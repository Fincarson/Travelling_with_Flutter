part of travel_agent_app;

class GroupChatRepository {
  GroupChatRepository(this._firestore, {FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _chatsRef =>
      _firestore.collection('chat_groups');

  CollectionReference<Map<String, dynamic>> get _invitesRef =>
      _firestore.collection('chat_invites');

  CollectionReference<Map<String, dynamic>> get _publicUsersRef =>
      _firestore.collection('public_users');

  DocumentReference<Map<String, dynamic>> _userDoc(String accountId) =>
      _firestore.collection('travel_users').doc(accountId);

  CollectionReference<Map<String, dynamic>> _membershipsRef(String accountId) =>
      _userDoc(accountId).collection('chatMemberships');

  CollectionReference<Map<String, dynamic>> _userInvitesRef(String accountId) =>
      _userDoc(accountId).collection('chatInvites');

  DocumentReference<Map<String, dynamic>> _chatDoc(String chatId) =>
      _chatsRef.doc(chatId);

  Future<void> upsertPublicUser({
    required AuthenticatedAccount account,
    required UserProfile profile,
  }) {
    return _publicUsersRef.doc(account.uid).set({
      'displayName': profile.name.trim().isEmpty ? account.name : profile.name,
      'emailLower': (account.email ?? profile.email).trim().toLowerCase(),
      'photoUrl': profile.photoUrl ?? account.photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<GroupChatMembership>> watchMemberships(String accountId) {
    return _membershipsRef(accountId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(GroupChatMembership.fromDoc).toList(),
        );
  }

  Future<GroupChatMembership?> loadMembership({
    required String accountId,
    required String chatId,
  }) async {
    final snapshot = await _membershipsRef(accountId).doc(chatId).get();
    if (!snapshot.exists) return null;
    return GroupChatMembership.fromDoc(snapshot);
  }

  Stream<List<GroupChatInvite>> watchPendingInvites(String accountId) {
    return _userInvitesRef(accountId).snapshots().map((snapshot) {
      final invites = snapshot.docs
          .map(GroupChatInvite.fromDoc)
          .where(
            (invite) => invite.status == GroupChatInviteStatus.pending.name,
          )
          .toList();
      invites.sort((a, b) {
        final bTime = b.expiresAt?.millisecondsSinceEpoch ?? 0;
        final aTime = a.expiresAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return invites;
    });
  }

  Stream<List<GroupChatMessage>> watchMessages(String chatId) {
    return _chatDoc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .limitToLast(120)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(GroupChatMessage.fromDoc).toList(),
        );
  }

  Stream<GroupChat?> watchChat(String chatId) {
    return _chatDoc(chatId).snapshots().map(
      (snapshot) => snapshot.exists ? GroupChat.fromDoc(snapshot) : null,
    );
  }

  Stream<List<GroupChatMember>> watchMembers(String chatId) {
    return _chatDoc(chatId).collection('members').snapshots().map((snapshot) {
      final members = snapshot.docs
          .map(GroupChatMember.fromDoc)
          .where((member) => member.isActive)
          .toList();
      members.sort((a, b) {
        final roleOrder = {
          GroupChatRole.owner.name: 0,
          GroupChatRole.admin.name: 1,
          GroupChatRole.member.name: 2,
        };
        final roleComparison = (roleOrder[a.role] ?? 3).compareTo(
          roleOrder[b.role] ?? 3,
        );
        if (roleComparison != 0) return roleComparison;
        return a.displayNameSnapshot.toLowerCase().compareTo(
          b.displayNameSnapshot.toLowerCase(),
        );
      });
      return members;
    });
  }

  Stream<List<GroupChatMessage>> watchSharedContent(String chatId) {
    return _chatDoc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(GroupChatMessage.fromDoc)
              .where(
                (message) =>
                    message.attachments.isNotEmpty ||
                    _firstUrlIn(message.text) != null,
              )
              .toList(),
        );
  }

  Future<GroupChat?> loadChat(String chatId) async {
    final snapshot = await _chatDoc(chatId).get();
    if (!snapshot.exists) return null;
    return GroupChat.fromDoc(snapshot);
  }

  Future<GroupChat> createChat({
    required String accountId,
    required UserProfile profile,
    required String title,
  }) async {
    final cleanTitle = _cleanChatTitle(title);
    final chatId = _newChatId();
    final chatRef = _chatDoc(chatId);
    final membershipRef = _membershipsRef(accountId).doc(chatId);
    final memberRef = chatRef.collection('members').doc(accountId);
    final now = FieldValue.serverTimestamp();

    final batch = _firestore.batch();
    batch.set(chatRef, {
      'title': cleanTitle,
      'ownerId': accountId,
      'memberIds': [accountId],
      'roles': {accountId: GroupChatRole.owner.name},
      'description': '',
      'linkedTripId': null,
      'type': 'group',
      'lastMessageText': '',
      'createdAt': now,
      'updatedAt': now,
    });
    batch.set(memberRef, {
      'role': GroupChatRole.owner.name,
      'status': GroupChatMemberStatus.active.name,
      'displayNameSnapshot': _displayNameFor(profile),
      'photoUrlSnapshot': profile.photoUrl,
      'joinedAt': now,
      'invitedBy': accountId,
      'updatedAt': now,
    });
    batch.set(membershipRef, {
      'chatId': chatId,
      'role': GroupChatRole.owner.name,
      'status': GroupChatMemberStatus.active.name,
      'titleSnapshot': cleanTitle,
      'lastMessageText': '',
      'unreadCount': 0,
      'mutedUntil': null,
      'mutedForever': false,
      'createdAt': now,
      'updatedAt': now,
    });
    await batch.commit();
    final chat = await loadChat(chatId);
    return chat ??
        GroupChat(
          id: chatId,
          title: cleanTitle,
          ownerId: accountId,
          memberIds: [accountId],
          roles: {accountId: GroupChatRole.owner.name},
        );
  }

  Future<void> sendMessage({
    required String chatId,
    required String accountId,
    required UserProfile profile,
    required String text,
    String? senderPhotoUrl,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final chat = await loadChat(chatId);
    if (chat == null) throw StateError('Chat not found.');

    final now = FieldValue.serverTimestamp();
    final messageRef = _chatDoc(chatId).collection('messages').doc();
    final batch = _firestore.batch();
    batch.set(messageRef, {
      'senderId': accountId,
      'senderNameSnapshot': _displayNameFor(profile),
      'senderPhotoUrlSnapshot': senderPhotoUrl,
      'text': cleanText,
      'type': 'text',
      'attachments': const <Map<String, dynamic>>[],
      'createdAt': now,
      'editedAt': null,
    });
    batch.set(_chatDoc(chatId), {
      'lastMessageText': cleanText,
      'lastMessageAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
    for (final memberId in chat.memberIds) {
      batch.set(_membershipsRef(memberId).doc(chatId), {
        'chatId': chatId,
        'titleSnapshot': chat.title,
        'lastMessageText': cleanText,
        'lastMessageAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> sendAttachment({
    required String chatId,
    required String accountId,
    required UserProfile profile,
    required PendingChatAttachment attachment,
    String? senderPhotoUrl,
    String caption = '',
  }) async {
    if (attachment.sizeBytes > ChatAttachmentService.maximumUploadBytes) {
      throw StateError('The selected file must be smaller than 50 MB.');
    }
    final chat = await loadChat(chatId);
    if (chat == null) throw StateError('Chat not found.');

    final messageRef = _chatDoc(chatId).collection('messages').doc();
    final safeName = _safeStorageName(attachment.name);
    final storagePath = 'chat_attachments/$chatId/${messageRef.id}/$safeName';
    final storageRef = _storage.ref(storagePath);
    var uploaded = false;
    try {
      await storageRef.putData(
        attachment.bytes,
        SettableMetadata(
          contentType: attachment.mimeType,
          cacheControl: 'private,max-age=3600',
          customMetadata: {'uploaderId': accountId, 'messageId': messageRef.id},
        ),
      );
      uploaded = true;
      final url = await storageRef.getDownloadURL();
      final now = FieldValue.serverTimestamp();
      final cleanCaption = caption.trim();
      final preview = cleanCaption.isEmpty
          ? _attachmentPreviewText(attachment)
          : cleanCaption;
      final attachmentData = <String, dynamic>{
        'type': attachment.type,
        'storagePath': storagePath,
        'url': url,
        'name': attachment.name,
        'mimeType': attachment.mimeType,
        'sizeBytes': attachment.sizeBytes,
      };
      final batch = _firestore.batch();
      batch.set(messageRef, {
        'senderId': accountId,
        'senderNameSnapshot': _displayNameFor(profile),
        'senderPhotoUrlSnapshot': senderPhotoUrl,
        'text': cleanCaption,
        'type': 'attachment',
        'attachments': [attachmentData],
        'createdAt': now,
        'editedAt': null,
      });
      batch.set(_chatDoc(chatId), {
        'lastMessageText': preview,
        'lastMessageAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
      for (final memberId in chat.memberIds) {
        batch.set(_membershipsRef(memberId).doc(chatId), {
          'chatId': chatId,
          'titleSnapshot': chat.title,
          'lastMessageText': preview,
          'lastMessageAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (_) {
      if (uploaded) {
        try {
          await storageRef.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> updateChatDetails({
    required String chatId,
    required String actorId,
    required String title,
    required String description,
  }) async {
    final chat = await _requireManageableChat(chatId, actorId);
    final cleanTitle = _cleanChatTitle(title);
    final cleanDescription = _cleanChatDescription(description);
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.set(_chatDoc(chatId), {
      'title': cleanTitle,
      'description': cleanDescription,
      'updatedAt': now,
    }, SetOptions(merge: true));
    for (final memberId in chat.memberIds) {
      batch.set(_membershipsRef(memberId).doc(chatId), {
        'titleSnapshot': cleanTitle,
        'updatedAt': now,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> updateMemberRole({
    required String chatId,
    required String actorId,
    required String memberId,
    required GroupChatRole role,
  }) async {
    if (role == GroupChatRole.owner) {
      throw StateError('Ownership transfer is not available yet.');
    }
    final chat = await _requireManageableChat(chatId, actorId);
    if (memberId == chat.ownerId) {
      throw StateError("The owner's role cannot be changed.");
    }
    if (!chat.memberIds.contains(memberId)) {
      throw StateError('That person is no longer in this chat.');
    }
    final roles = {...chat.roles, memberId: role.name};
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.set(_chatDoc(chatId), {
      'roles': roles,
      'updatedAt': now,
    }, SetOptions(merge: true));
    batch.set(
      _chatDoc(chatId).collection('members').doc(memberId),
      {'role': role.name, 'updatedAt': now},
      SetOptions(merge: true),
    );
    batch.set(_membershipsRef(memberId).doc(chatId), {
      'role': role.name,
      'updatedAt': now,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> removeMember({
    required String chatId,
    required String actorId,
    required String memberId,
  }) async {
    await _removeActiveMember(
      chatId: chatId,
      actorId: actorId,
      memberId: memberId,
      isLeaving: false,
    );
  }

  Future<void> leaveChat({
    required String chatId,
    required String accountId,
  }) async {
    await _removeActiveMember(
      chatId: chatId,
      actorId: accountId,
      memberId: accountId,
      isLeaving: true,
    );
  }

  Future<void> setMute({
    required String chatId,
    required String accountId,
    DateTime? until,
    bool forever = false,
  }) {
    return _membershipsRef(accountId).doc(chatId).set({
      'mutedForever': forever,
      'mutedUntil': forever || until == null
          ? null
          : Timestamp.fromDate(until.toUtc()),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<GroupChat> _requireManageableChat(
    String chatId,
    String actorId,
  ) async {
    final chat = await loadChat(chatId);
    if (chat == null) throw StateError('Chat not found.');
    final role = chat.roles[actorId];
    if (role != GroupChatRole.owner.name && role != GroupChatRole.admin.name) {
      throw StateError('Only the owner or an admin can do that.');
    }
    return chat;
  }

  Future<void> _removeActiveMember({
    required String chatId,
    required String actorId,
    required String memberId,
    required bool isLeaving,
  }) async {
    final chat = await loadChat(chatId);
    if (chat == null) throw StateError('Chat not found.');
    if (memberId == chat.ownerId) {
      throw StateError(
        'The owner must transfer ownership before leaving the chat.',
      );
    }
    if (!isLeaving) {
      final actorRole = chat.roles[actorId];
      if (actorRole != GroupChatRole.owner.name &&
          actorRole != GroupChatRole.admin.name) {
        throw StateError('Only the owner or an admin can remove members.');
      }
    } else if (actorId != memberId) {
      throw StateError('You can only leave for your own account.');
    }
    if (!chat.memberIds.contains(memberId)) return;

    final roles = {...chat.roles}..remove(memberId);
    final memberIds = [...chat.memberIds]..remove(memberId);
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.set(_chatDoc(chatId), {
      'memberIds': memberIds,
      'roles': roles,
      'updatedAt': now,
    }, SetOptions(merge: true));
    batch.set(
      _chatDoc(chatId).collection('members').doc(memberId),
      {'status': GroupChatMemberStatus.left.name, 'updatedAt': now},
      SetOptions(merge: true),
    );
    batch.set(_membershipsRef(memberId).doc(chatId), {
      'status': GroupChatMemberStatus.left.name,
      'updatedAt': now,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<GroupChatInvite> createShareInvite({
    required String chatId,
    required String inviterId,
    required UserProfile inviter,
  }) async {
    final chat = await loadChat(chatId);
    if (chat == null) throw StateError('Chat not found.');
    final code = _newInviteCode();
    final invite = GroupChatInvite(
      code: code,
      chatId: chatId,
      titleSnapshot: chat.title,
      role: GroupChatRole.member.name,
      status: GroupChatInviteStatus.pending.name,
      invitedBy: inviterId,
      inviterNameSnapshot: _displayNameFor(inviter),
      expiresAt: Timestamp.fromDate(
        DateTime.now().toUtc().add(const Duration(days: 14)),
      ),
    );
    await _writeInvite(invite: invite, userInviteeId: null);
    return invite;
  }

  Future<GroupChatInvite> inviteByUserInput({
    required String chatId,
    required String inviterId,
    required UserProfile inviter,
    required String input,
  }) async {
    final target = await findUserByUidOrEmail(input);
    if (target == null) {
      throw StateError('No user found for that ID or email.');
    }
    if (target.uid == inviterId) {
      throw StateError('You are already in this chat.');
    }
    final chat = await loadChat(chatId);
    if (chat == null) throw StateError('Chat not found.');
    if (chat.memberIds.contains(target.uid)) {
      throw StateError('That user is already in this chat.');
    }
    final code = _newInviteCode();
    final invite = GroupChatInvite(
      code: code,
      chatId: chatId,
      titleSnapshot: chat.title,
      role: GroupChatRole.member.name,
      status: GroupChatInviteStatus.pending.name,
      invitedBy: inviterId,
      inviterNameSnapshot: _displayNameFor(inviter),
      inviteeUid: target.uid,
      inviteeEmail: target.emailLower,
      expiresAt: Timestamp.fromDate(
        DateTime.now().toUtc().add(const Duration(days: 14)),
      ),
    );

    final batch = _firestore.batch();
    _setInviteDocuments(batch, invite: invite, userInviteeId: target.uid);
    batch.set(
      _chatDoc(chatId).collection('members').doc(target.uid),
      {
        'role': GroupChatRole.member.name,
        'status': GroupChatMemberStatus.invited.name,
        'displayNameSnapshot': target.displayName,
        'photoUrlSnapshot': target.photoUrl,
        'invitedBy': inviterId,
        'inviteCode': invite.code,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(_membershipsRef(target.uid).doc(chatId), {
      'chatId': chatId,
      'role': GroupChatRole.member.name,
      'status': GroupChatMemberStatus.invited.name,
      'titleSnapshot': chat.title,
      'lastMessageText': chat.lastMessageText,
      'lastMessageAt': chat.lastMessageAt,
      'unreadCount': 0,
      'mutedUntil': null,
      'mutedForever': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    return invite;
  }

  Future<PublicChatUser?> findUserByUidOrEmail(String input) async {
    final text = input.trim();
    if (text.isEmpty) return null;
    if (!text.contains('@')) {
      final snapshot = await _publicUsersRef.doc(text).get();
      return snapshot.exists ? PublicChatUser.fromDoc(snapshot) : null;
    }
    final query = await _publicUsersRef
        .where('emailLower', isEqualTo: text.toLowerCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return PublicChatUser.fromDoc(query.docs.first);
  }

  Future<GroupChatInvite> loadInvite(String inviteCode) async {
    final code = _inviteCodeFromText(inviteCode);
    final snapshot = await _invitesRef.doc(code).get();
    if (!snapshot.exists) throw StateError('Invite not found.');
    return GroupChatInvite.fromDoc(snapshot);
  }

  Future<String> acceptInvite({
    required String inviteCode,
    required String accountId,
    required UserProfile profile,
  }) async {
    final invite = await loadInvite(inviteCode);
    if (invite.status != GroupChatInviteStatus.pending.name) {
      throw StateError('This invite is no longer available.');
    }
    final expiresAt = invite.expiresAt?.toDate().toUtc();
    if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
      throw StateError('This invite has expired.');
    }
    if (invite.inviteeUid != null && invite.inviteeUid != accountId) {
      throw StateError('This invite is for another account.');
    }

    final chat = await loadChat(invite.chatId);
    if (chat == null) throw StateError('Chat not found.');
    final roles = {...chat.roles, accountId: invite.role};
    final acceptedAt = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.set(_chatDoc(invite.chatId), {
      'memberIds': FieldValue.arrayUnion([accountId]),
      'roles': roles,
      'updatedAt': acceptedAt,
    }, SetOptions(merge: true));
    batch.set(
      _chatDoc(invite.chatId).collection('members').doc(accountId),
      {
        'role': invite.role,
        'status': GroupChatMemberStatus.active.name,
        'displayNameSnapshot': _displayNameFor(profile),
        'photoUrlSnapshot': profile.photoUrl,
        'joinedAt': acceptedAt,
        'invitedBy': invite.invitedBy,
        'inviteCode': invite.code,
        'updatedAt': acceptedAt,
      },
      SetOptions(merge: true),
    );
    batch.set(_membershipsRef(accountId).doc(invite.chatId), {
      'chatId': invite.chatId,
      'role': invite.role,
      'status': GroupChatMemberStatus.active.name,
      'titleSnapshot': chat.title,
      'lastMessageText': chat.lastMessageText,
      'lastMessageAt': chat.lastMessageAt,
      'unreadCount': 0,
      'mutedUntil': null,
      'mutedForever': false,
      'updatedAt': acceptedAt,
    }, SetOptions(merge: true));
    _updateInviteStatus(batch, invite, GroupChatInviteStatus.accepted.name);
    await batch.commit();
    return invite.chatId;
  }

  Future<void> declineInvite({
    required String inviteCode,
    required String accountId,
  }) async {
    final invite = await loadInvite(inviteCode);
    final batch = _firestore.batch();
    _updateInviteStatus(batch, invite, GroupChatInviteStatus.rejected.name);
    batch.set(_membershipsRef(accountId).doc(invite.chatId), {
      'status': GroupChatMemberStatus.left.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(
      _chatDoc(invite.chatId).collection('members').doc(accountId),
      {
        'status': GroupChatMemberStatus.left.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> _writeInvite({
    required GroupChatInvite invite,
    String? userInviteeId,
  }) async {
    final batch = _firestore.batch();
    _setInviteDocuments(batch, invite: invite, userInviteeId: userInviteeId);
    await batch.commit();
  }

  void _setInviteDocuments(
    WriteBatch batch, {
    required GroupChatInvite invite,
    required String? userInviteeId,
  }) {
    final map = _inviteMap(invite);
    batch.set(_invitesRef.doc(invite.code), map);
    batch.set(
      _chatDoc(invite.chatId).collection('invites').doc(invite.code),
      map,
    );
    if (userInviteeId != null) {
      batch.set(_userInvitesRef(userInviteeId).doc(invite.code), map);
    }
  }

  void _updateInviteStatus(
    WriteBatch batch,
    GroupChatInvite invite,
    String status,
  ) {
    final patch = {'status': status, 'updatedAt': FieldValue.serverTimestamp()};
    batch.set(_invitesRef.doc(invite.code), patch, SetOptions(merge: true));
    batch.set(
      _chatDoc(invite.chatId).collection('invites').doc(invite.code),
      patch,
      SetOptions(merge: true),
    );
    if (invite.inviteeUid != null) {
      batch.set(
        _userInvitesRef(invite.inviteeUid!).doc(invite.code),
        patch,
        SetOptions(merge: true),
      );
    }
  }

  Map<String, dynamic> _inviteMap(GroupChatInvite invite) => {
    'inviteCode': invite.code,
    'chatId': invite.chatId,
    'titleSnapshot': invite.titleSnapshot,
    'role': invite.role,
    'status': invite.status,
    'invitedBy': invite.invitedBy,
    'inviterNameSnapshot': invite.inviterNameSnapshot,
    'inviteeUid': invite.inviteeUid,
    'inviteeEmail': invite.inviteeEmail,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'expiresAt': invite.expiresAt,
  };
}

String _displayNameFor(UserProfile profile) =>
    profile.name.trim().isEmpty ? 'Explorer' : profile.name.trim();

String _cleanChatTitle(String value) {
  final title = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (title.isEmpty) return 'New chat';
  if (title.length <= 60) return title;
  return title.substring(0, 60).trim();
}

String _cleanChatDescription(String value) {
  final description = value.trim();
  if (description.length <= 500) return description;
  return description.substring(0, 500).trim();
}

String _safeStorageName(String value) {
  final clean = value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  final fallback = clean.isEmpty ? 'attachment' : clean;
  return '${DateTime.now().millisecondsSinceEpoch}_$fallback';
}

String _attachmentPreviewText(PendingChatAttachment attachment) {
  return switch (attachment.type) {
    'image' => 'Photo',
    'gif' => 'GIF',
    'video' => 'Video',
    'pdf' => 'PDF: ${attachment.name}',
    _ => 'File: ${attachment.name}',
  };
}

Uri? _firstUrlIn(String value) {
  final match = RegExp(
    r'https?://[^\s<>()]+',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) return null;
  final raw = match.group(0);
  return raw == null ? null : Uri.tryParse(raw);
}

String _newChatId() =>
    'chat-${DateTime.now().millisecondsSinceEpoch}-${_randomCode(6)}';

String _newInviteCode() => _randomCode(24);

String _randomCode(int length) {
  const chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = math.Random.secure();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

String _inviteCodeFromText(String value) {
  final text = value.trim();
  if (text.contains('/')) {
    final uri = Uri.tryParse(text);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last.trim();
    }
  }
  return text;
}
