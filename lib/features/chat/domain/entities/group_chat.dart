part of travel_agent_app;

enum GroupChatRole { owner, admin, member }

enum GroupChatMemberStatus { active, invited, left }

enum GroupChatInviteStatus { pending, accepted, rejected, expired }

class GroupChat {
  const GroupChat({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.memberIds,
    required this.roles,
    this.linkedTripId,
    this.type = 'group',
    this.lastMessageText = '',
    this.lastMessageAt,
  });

  final String id;
  final String title;
  final String ownerId;
  final List<String> memberIds;
  final Map<String, String> roles;
  final String? linkedTripId;
  final String type;
  final String lastMessageText;
  final Timestamp? lastMessageAt;

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
      linkedTripId: map['linkedTripId'] as String?,
      type: (map['type'] as String?) ?? 'group',
      lastMessageText: (map['lastMessageText'] as String?) ?? '',
      lastMessageAt: map['lastMessageAt'] as Timestamp?,
    );
  }
}

class GroupChatMembership {
  const GroupChatMembership({
    required this.chatId,
    required this.role,
    required this.status,
    required this.titleSnapshot,
    this.lastMessageText = '',
    this.lastMessageAt,
  });

  final String chatId;
  final String role;
  final String status;
  final String titleSnapshot;
  final String lastMessageText;
  final Timestamp? lastMessageAt;

  bool get isActive => status == GroupChatMemberStatus.active.name;

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
