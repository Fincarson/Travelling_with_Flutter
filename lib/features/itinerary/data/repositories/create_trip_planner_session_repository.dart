part of travel_agent_app;

class CreateTripPlannerSession {
  const CreateTripPlannerSession({
    required this.messages,
    required this.pendingDraft,
    required this.pendingDraftConfirmed,
    required this.currency,
    required this.pendingPreviewData,
    required this.isPreparingPreview,
  });

  final List<CreateTripChatMessage> messages;
  final CreateTripDraft? pendingDraft;
  final bool pendingDraftConfirmed;
  final String currency;
  final Map<String, dynamic>? pendingPreviewData;
  final bool isPreparingPreview;

  bool get isEmpty =>
      messages.isEmpty &&
      pendingDraft == null &&
      pendingPreviewData == null &&
      !isPreparingPreview;

  Map<String, dynamic> toMap() => {
    'messages': messages.map((message) => message.toMap()).toList(),
    'pendingDraft': pendingDraft?.toMap(),
    'pendingDraftConfirmed': pendingDraftConfirmed,
    'currency': currency,
    'pendingPreview': pendingPreviewData,
    'isPreparingPreview': isPreparingPreview,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static CreateTripPlannerSession fromMap(Map<String, dynamic> map) {
    final draftMap = map['pendingDraft'] is Map
        ? Map<String, dynamic>.from(map['pendingDraft'] as Map)
        : null;
    return CreateTripPlannerSession(
      messages: ((map['messages'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                CreateTripChatMessage.fromMap(Map<String, dynamic>.from(item)),
          )
          .where((message) => message.text.trim().isNotEmpty)
          .take(40)
          .toList(),
      pendingDraft: draftMap == null ? null : CreateTripDraft.fromMap(draftMap),
      pendingDraftConfirmed: map['pendingDraftConfirmed'] == true,
      currency:
          (map['currency'] as String?) ?? AppCurrency.fallbackCurrencyCode,
      pendingPreviewData: map['pendingPreview'] is Map
          ? Map<String, dynamic>.from(map['pendingPreview'] as Map)
          : null,
      isPreparingPreview: map['isPreparingPreview'] == true,
    );
  }
}

class CreateTripPlannerSessionRepository {
  const CreateTripPlannerSessionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _sessionRef(String accountId) =>
      _firestore
          .collection('travel_users')
          .doc(accountId)
          .collection('createTripPlannerSessions')
          .doc('current');

  Stream<CreateTripPlannerSession?> watchCurrentSession(String accountId) {
    return _sessionRef(accountId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return CreateTripPlannerSession.fromMap(
        snapshot.data() ?? const <String, dynamic>{},
      );
    });
  }

  Future<void> saveCurrentSession(
    String accountId,
    CreateTripPlannerSession session,
  ) {
    return _sessionRef(accountId).set(session.toMap(), SetOptions(merge: true));
  }

  Future<void> clearCurrentSession(String accountId) {
    return _sessionRef(accountId).delete();
  }
}
