part of travel_agent_app;

enum GroupChatRole { owner, admin, member }

enum GroupChatMemberStatus { active, invited, left }

enum GroupChatInviteStatus { pending, accepted, rejected, expired }

class PendingChatAttachment {
  const PendingChatAttachment({
    required this.name,
    required this.mimeType,
    required this.type,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final String type;
  final Uint8List bytes;

  int get sizeBytes => bytes.lengthInBytes;
}

class ChatPollDraft {
  const ChatPollDraft({required this.question, required this.options});

  final String question;
  final List<String> options;
}

class ChatPoll {
  const ChatPoll({required this.question, required this.options});

  final String question;
  final List<String> options;

  static ChatPoll? fromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final question = (map['question'] as String?)?.trim() ?? '';
    final options = ((map['options'] as List<dynamic>?) ?? const [])
        .whereType<String>()
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList(growable: false);
    if (question.isEmpty || options.length < 2) return null;
    return ChatPoll(question: question, options: options);
  }

  Map<String, dynamic> toMap() => {'question': question, 'options': options};
}

class GroupChat {
  const GroupChat({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.memberIds,
    required this.roles,
    this.description = '',
    this.linkedTripId,
    this.linkedTripTitle,
    this.linkedTripDestination,
    this.linkedTripCoverImageUrl,
    this.type = 'group',
    this.lastMessageText = '',
    this.lastMessageAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String ownerId;
  final List<String> memberIds;
  final Map<String, String> roles;
  final String description;
  final String? linkedTripId;
  final String? linkedTripTitle;
  final String? linkedTripDestination;
  final String? linkedTripCoverImageUrl;
  final String type;
  final String lastMessageText;
  final Timestamp? lastMessageAt;
  final Timestamp? createdAt;

  static GroupChat fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const <String, dynamic>{};
    return GroupChat(
      id: doc.id,
      title: (map['title'] as String?) ?? 'New chat',
      ownerId: (map['ownerId'] as String?) ?? '',
      memberIds: ((map['memberIds'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList(),
      roles: Map<String, String>.from(
        ((map['roles'] as Map?) ?? const <String, dynamic>{}).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      ),
      description: (map['description'] as String?) ?? '',
      linkedTripId: map['linkedTripId'] as String?,
      linkedTripTitle: map['linkedTripTitle'] as String?,
      linkedTripDestination: map['linkedTripDestination'] as String?,
      linkedTripCoverImageUrl: map['linkedTripCoverImageUrl'] as String?,
      type: (map['type'] as String?) ?? 'group',
      lastMessageText: (map['lastMessageText'] as String?) ?? '',
      lastMessageAt: map['lastMessageAt'] as Timestamp?,
      createdAt: map['createdAt'] as Timestamp?,
    );
  }
}

class ChatTripSummary {
  const ChatTripSummary({
    required this.id,
    required this.title,
    required this.destination,
    this.coverImageUrl,
  });

  final String id;
  final String title;
  final String destination;
  final String? coverImageUrl;
}

class GroupChatMembership {
  const GroupChatMembership({
    required this.chatId,
    required this.role,
    required this.status,
    required this.titleSnapshot,
    this.lastMessageText = '',
    this.lastMessageAt,
    this.mutedUntil,
    this.mutedForever = false,
  });

  final String chatId;
  final String role;
  final String status;
  final String titleSnapshot;
  final String lastMessageText;
  final Timestamp? lastMessageAt;
  final Timestamp? mutedUntil;
  final bool mutedForever;

  bool get isActive => status == GroupChatMemberStatus.active.name;
  bool get isMuted {
    if (mutedForever) return true;
    final until = mutedUntil?.toDate();
    return until != null && until.isAfter(DateTime.now());
  }

  static GroupChatMembership fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = doc.data() ?? const <String, dynamic>{};
    return GroupChatMembership(
      chatId: (map['chatId'] as String?) ?? doc.id,
      role: (map['role'] as String?) ?? GroupChatRole.member.name,
      status: (map['status'] as String?) ?? GroupChatMemberStatus.active.name,
      titleSnapshot: (map['titleSnapshot'] as String?) ?? 'New chat',
      lastMessageText: (map['lastMessageText'] as String?) ?? '',
      lastMessageAt: map['lastMessageAt'] as Timestamp?,
      mutedUntil: map['mutedUntil'] as Timestamp?,
      mutedForever: (map['mutedForever'] as bool?) ?? false,
    );
  }
}

class GroupChatMember {
  const GroupChatMember({
    required this.uid,
    required this.role,
    required this.status,
    required this.displayNameSnapshot,
    this.photoUrlSnapshot,
    this.joinedAt,
  });

  final String uid;
  final String role;
  final String status;
  final String displayNameSnapshot;
  final String? photoUrlSnapshot;
  final Timestamp? joinedAt;

  bool get isActive => status == GroupChatMemberStatus.active.name;
  bool get isOwner => role == GroupChatRole.owner.name;

  static GroupChatMember fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const <String, dynamic>{};
    return GroupChatMember(
      uid: doc.id,
      role: (map['role'] as String?) ?? GroupChatRole.member.name,
      status: (map['status'] as String?) ?? GroupChatMemberStatus.active.name,
      displayNameSnapshot:
          (map['displayNameSnapshot'] as String?) ?? 'Explorer',
      photoUrlSnapshot: map['photoUrlSnapshot'] as String?,
      joinedAt: map['joinedAt'] as Timestamp?,
    );
  }
}

class GroupChatMessage {
  const GroupChatMessage({
    required this.id,
    required this.senderId,
    required this.senderNameSnapshot,
    required this.text,
    required this.type,
    this.senderPhotoUrlSnapshot,
    this.attachments = const [],
    this.poll,
    this.createdAt,
    this.editedAt,
  });

  final String id;
  final String senderId;
  final String senderNameSnapshot;
  final String? senderPhotoUrlSnapshot;
  final String text;
  final String type;
  final List<Map<String, dynamic>> attachments;
  final ChatPoll? poll;
  final Timestamp? createdAt;
  final Timestamp? editedAt;

  static GroupChatMessage fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const <String, dynamic>{};
    return GroupChatMessage(
      id: doc.id,
      senderId: (map['senderId'] as String?) ?? '',
      senderNameSnapshot: (map['senderNameSnapshot'] as String?) ?? 'Someone',
      senderPhotoUrlSnapshot: map['senderPhotoUrlSnapshot'] as String?,
      text: (map['text'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'text',
      attachments: ((map['attachments'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      poll: ChatPoll.fromMap(map['poll']),
      createdAt: map['createdAt'] as Timestamp?,
      editedAt: map['editedAt'] as Timestamp?,
    );
  }
}

class GroupChatInvite {
  const GroupChatInvite({
    required this.code,
    required this.chatId,
    required this.titleSnapshot,
    required this.role,
    required this.status,
    required this.invitedBy,
    this.inviterNameSnapshot = '',
    this.inviteeUid,
    this.inviteeEmail,
    this.expiresAt,
  });

  final String code;
  final String chatId;
  final String titleSnapshot;
  final String role;
  final String status;
  final String invitedBy;
  final String inviterNameSnapshot;
  final String? inviteeUid;
  final String? inviteeEmail;
  final Timestamp? expiresAt;

  String get link => 'https://travelling-with-flutter.web.app/invite/$code';

  static GroupChatInvite fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const <String, dynamic>{};
    return GroupChatInvite(
      code: (map['inviteCode'] as String?) ?? doc.id,
      chatId: (map['chatId'] as String?) ?? '',
      titleSnapshot: (map['titleSnapshot'] as String?) ?? 'New chat',
      role: (map['role'] as String?) ?? GroupChatRole.member.name,
      status: (map['status'] as String?) ?? GroupChatInviteStatus.pending.name,
      invitedBy: (map['invitedBy'] as String?) ?? '',
      inviterNameSnapshot: (map['inviterNameSnapshot'] as String?) ?? '',
      inviteeUid: map['inviteeUid'] as String?,
      inviteeEmail: map['inviteeEmail'] as String?,
      expiresAt: map['expiresAt'] as Timestamp?,
    );
  }
}

class GroupChatJoinResult {
  const GroupChatJoinResult({
    required this.chatId,
    required this.title,
    required this.role,
    required this.alreadyMember,
  });

  final String chatId;
  final String title;
  final String role;
  final bool alreadyMember;

  static GroupChatJoinResult fromMap(Map<String, dynamic> map) {
    return GroupChatJoinResult(
      chatId: (map['chatId'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Group chat',
      role: (map['role'] as String?) ?? GroupChatRole.member.name,
      alreadyMember: (map['alreadyMember'] as bool?) ?? false,
    );
  }
}

class PublicChatUser {
  const PublicChatUser({
    required this.uid,
    required this.displayName,
    required this.emailLower,
    this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String emailLower;
  final String? photoUrl;

  static PublicChatUser fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const <String, dynamic>{};
    return PublicChatUser(
      uid: doc.id,
      displayName: (map['displayName'] as String?) ?? 'Explorer',
      emailLower: (map['emailLower'] as String?) ?? '',
      photoUrl: map['photoUrl'] as String?,
    );
  }
}
