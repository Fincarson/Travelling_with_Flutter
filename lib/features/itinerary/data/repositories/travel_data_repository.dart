part of travel_agent_app;

class TravelDataRepository {
  const TravelDataRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String accountId) =>
      _firestore.collection('travel_users').doc(accountId);

  DocumentReference<Map<String, dynamic>> _publicUserDoc(String accountId) =>
      _firestore.collection('public_users').doc(accountId);

  CollectionReference<Map<String, dynamic>> _legacyTripsRef(String accountId) =>
      _userDoc(accountId).collection('trips');

  CollectionReference<Map<String, dynamic>> _membershipsRef(String accountId) =>
      _userDoc(accountId).collection('tripMemberships');

  CollectionReference<Map<String, dynamic>> _memoriesRef(String accountId) =>
      _userDoc(accountId).collection('tripMemories');

  CollectionReference<Map<String, dynamic>> get _sharedTripsRef =>
      _firestore.collection('trips');

  DocumentReference<Map<String, dynamic>> _sharedTripDoc(String tripId) =>
      _sharedTripsRef.doc(tripId);

  Future<UserProfile?> loadUser(String accountId) async {
    final snapshot = await _userDoc(accountId).get();
    if (!snapshot.exists) return null;
    return UserProfile.fromMap(snapshot.data() ?? const <String, dynamic>{});
  }

  Stream<UserProfile?> watchUser(String accountId) {
    return _userDoc(accountId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserProfile.fromMap(snapshot.data() ?? const <String, dynamic>{});
    });
  }

  Future<void> saveUser(String accountId, UserProfile profile) {
    final batch = _firestore.batch();
    batch.set(_userDoc(accountId), profile.toMap(), SetOptions(merge: true));
    batch.set(_publicUserDoc(accountId), {
      'displayName': _displayNameFor(profile),
      'emailLower': profile.email.trim().toLowerCase(),
      'photoUrl': profile.photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return batch.commit();
  }

  Future<void> completeOnboarding(String accountId) {
    return _userDoc(accountId).set({
      'settings': {'onboardingRequired': false, 'onboardingCompleted': true},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Trip>> loadTrips(String accountId) async {
    await migrateLegacyTrips(accountId);
    final memberships = await _membershipsRef(accountId).get();
    return _tripsFromMemberships(memberships.docs);
  }

  Future<List<TripMemory>> loadTripMemories(String accountId) async {
    try {
      final snapshot = await _memoriesRef(accountId).get();
      return _memoriesFromDocs(snapshot.docs);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return const [];
      rethrow;
    }
  }

  Stream<List<TripMemory>> watchTripMemories(String accountId) {
    return _memoriesRef(
      accountId,
    ).snapshots().map((snapshot) => _memoriesFromDocs(snapshot.docs));
  }

  Future<void> archiveExpiredTrips(String accountId, {DateTime? now}) async {
    await migrateLegacyTrips(accountId);
    final memberships = await _membershipsRef(accountId).get();
    final trips = await _tripsFromMemberships(memberships.docs);
    final current = now ?? _travelAgentNow();

    for (final trip in trips) {
      if (!_shouldArchiveExpiredTrip(trip, current)) continue;
      try {
        await _memoriesRef(
          accountId,
        ).doc(trip.id).set(TripMemory.fromTrip(trip, now: current).toMap());
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
      }

      try {
        await _removeAccountFromTrip(accountId, trip.id);
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
        await _membershipsRef(accountId).doc(trip.id).delete();
      }
    }
  }

  Stream<List<Trip>> watchTrips(String accountId) {
    final controller = StreamController<List<Trip>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;

    Future<void>(() async {
      try {
        await migrateLegacyTrips(accountId);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }

      if (controller.isClosed) return;
      subscription = _membershipsRef(accountId).snapshots().listen(
        (snapshot) async {
          try {
            final trips = await _tripsFromMemberships(snapshot.docs);
            if (!controller.isClosed) controller.add(trips);
          } catch (error, stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
      );
    });

    controller.onCancel = () => subscription?.cancel();
    return controller.stream;
  }

  Future<void> saveTrip(String accountId, Trip trip) {
    return _writeSharedTrip(accountId: accountId, trip: trip);
  }

  Future<void> startTrip(
    String accountId, {
    required Trip trip,
    Trip? previousActive,
  }) async {
    await migrateLegacyTrips(accountId);
    final batch = _firestore.batch();
    if (previousActive != null && previousActive.id != trip.id) {
      batch.update(_sharedTripDoc(previousActive.id), {
        'status': TripStatus.upcoming.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_sharedTripDoc(trip.id), {
      'status': TripStatus.ongoing.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> deleteTrip(String accountId, String tripId) async {
    await migrateLegacyTrips(accountId);
    await _removeAccountFromTrip(accountId, tripId);
  }

  Future<void> migrateLegacyTrips(String accountId) async {
    final legacyTrips = await _legacyTripsRef(accountId).get();
    for (final legacyTrip in legacyTrips.docs) {
      final trip = Trip.fromDoc(legacyTrip);
      await _writeSharedTrip(accountId: accountId, trip: trip);
      await legacyTrip.reference.delete();
    }
  }

  Future<void> deleteUserData(String accountId) async {
    await migrateLegacyTrips(accountId);

    final memberships = await _membershipsRef(accountId).get();
    for (final membership in memberships.docs) {
      await _removeAccountFromTrip(accountId, membership.id);
    }

    final legacyTrips = await _legacyTripsRef(accountId).get();
    final cleanupBatch = _firestore.batch();
    for (final trip in legacyTrips.docs) {
      cleanupBatch.delete(trip.reference);
    }
    cleanupBatch.delete(_userDoc(accountId));
    await cleanupBatch.commit();
  }

  Future<List<Trip>> _tripsFromMemberships(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> memberships,
  ) async {
    final docs = [...memberships]
      ..sort((a, b) {
        final bUpdated = _timestampMillis(b.data()['updatedAt']);
        final aUpdated = _timestampMillis(a.data()['updatedAt']);
        return bUpdated.compareTo(aUpdated);
      });
    final trips = <Trip>[];
    for (final membership in docs) {
      final tripDoc = await _sharedTripDoc(membership.id).get();
      if (!tripDoc.exists) continue;
      trips.add(await _tripFromSharedDoc(tripDoc));
    }
    return trips;
  }

  List<TripMemory> _memoriesFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final memories = docs.map(TripMemory.fromDoc).toList();
    memories.sort((a, b) => b.archivedAtKey.compareTo(a.archivedAtKey));
    return memories;
  }

  Future<Trip> _tripFromSharedDoc(
    DocumentSnapshot<Map<String, dynamic>> tripDoc,
  ) async {
    final tripRef = tripDoc.reference;
    final snapshots = await Future.wait([
      tripRef.collection('itineraryItems').get(),
      tripRef.collection('bookings').get(),
      tripRef.collection('budgetCategories').get(),
    ]);

    final items =
        snapshots[0].docs
            .map((doc) => _orderedDocData(doc))
            .map(ScheduleItem.fromMap)
            .where((item) => !_isLegacyManualStarterItem(item))
            .toList()
          ..sort(_compareScheduleItems);

    final bookings =
        snapshots[1].docs
            .map((doc) => _orderedDocData(doc))
            .map(Booking.fromMap)
            .toList()
          ..sort(_compareBookings);

    final budgetCategories =
        snapshots[2].docs
            .map((doc) => _orderedDocData(doc))
            .map(BudgetCategory.fromMap)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    return Trip.fromSharedDoc(
      tripDoc,
      items: items,
      bookings: bookings,
      budgetCategories: budgetCategories,
    );
  }

  Future<void> _writeSharedTrip({
    required String accountId,
    required Trip trip,
  }) async {
    final tripRef = _sharedTripDoc(trip.id);
    final membership = await _membershipsRef(accountId).doc(trip.id).get();
    final existingTrip = membership.exists ? await tripRef.get() : null;
    final existingData = existingTrip?.data() ?? const <String, dynamic>{};
    final ownerId = (existingData['ownerId'] as String?) ?? accountId;
    final memberIds = _stringList(existingData['memberIds']);
    if (!memberIds.contains(accountId)) memberIds.add(accountId);
    if (memberIds.isEmpty) memberIds.add(accountId);

    final roles = Map<String, String>.from(
      ((existingData['roles'] as Map?) ?? const <String, dynamic>{}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
    roles.putIfAbsent(
      accountId,
      () => ownerId == accountId ? 'owner' : 'editor',
    );

    final user = await loadUser(accountId);
    final existingCollections = existingTrip == null
        ? <QuerySnapshot<Map<String, dynamic>>>[]
        : await Future.wait([
            tripRef.collection('itineraryItems').get(),
            tripRef.collection('bookings').get(),
            tripRef.collection('budgetCategories').get(),
          ]);

    final batch = _firestore.batch();
    batch.set(
      tripRef,
      _sharedTripMap(
        trip: trip,
        ownerId: ownerId,
        memberIds: memberIds,
        roles: roles,
        includeCreatedAt: existingTrip == null,
      ),
      SetOptions(merge: true),
    );

    for (final collection in existingCollections) {
      for (final doc in collection.docs) {
        batch.delete(doc.reference);
      }
    }
    _writeScheduleItems(batch, tripRef, trip.items);
    _writeBookings(batch, tripRef, trip.bookings);
    _writeBudgetCategories(batch, tripRef, trip.budgetCategories);

    batch.set(
      tripRef.collection('members').doc(accountId),
      _memberMap(
        accountId: accountId,
        role: roles[accountId] ?? 'editor',
        profile: user,
        invitedBy: accountId,
        includeJoinedAt: existingTrip == null,
      ),
      SetOptions(merge: true),
    );

    for (final memberId in memberIds) {
      batch.set(
        _membershipsRef(memberId).doc(trip.id),
        _membershipMap(
          trip: trip,
          role: roles[memberId] ?? 'viewer',
          status: 'active',
        ),
        SetOptions(merge: true),
      );
    }

    if (existingTrip == null) {
      batch.set(tripRef.collection('channels').doc('general'), {
        'title': 'Group chat',
        'type': 'group',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Map<String, dynamic> _sharedTripMap({
    required Trip trip,
    required String ownerId,
    required List<String> memberIds,
    required Map<String, String> roles,
    required bool includeCreatedAt,
  }) {
    final title = trip.title.trim().isEmpty ? trip.destination : trip.title;
    return {
      'ownerId': ownerId,
      'title': title,
      'destination': trip.destination,
      'placeId': trip.placeId,
      'formattedAddress': trip.formattedAddress,
      'latitude': trip.latitude,
      'longitude': trip.longitude,
      'startDate': trip.startDate,
      'endDate': trip.endDate,
      'budget': trip.budget,
      'spent': trip.spent,
      'currency': trip.currency,
      'status': trip.status.name,
      'numOfTravelers': trip.numOfTravelers,
      'memberIds': memberIds,
      'roles': roles,
      'images': trip.images,
      'preferences': trip.preferences,
      'checklist': trip.checklist.map((category) => category.toMap()).toList(),
      if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _membershipMap({
    required Trip trip,
    required String role,
    required String status,
  }) {
    final title = trip.title.trim().isEmpty ? trip.destination : trip.title;
    return {
      'tripId': trip.id,
      'role': role,
      'status': status,
      'titleSnapshot': title,
      'destinationSnapshot': trip.destination,
      'coverImageUrl': trip.images.isEmpty ? null : trip.images.first,
      'unreadCount': FieldValue.increment(0),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _memberMap({
    required String accountId,
    required String role,
    required UserProfile? profile,
    required String invitedBy,
    required bool includeJoinedAt,
  }) {
    return {
      'role': role,
      'status': 'active',
      'displayNameSnapshot': profile?.name ?? accountId,
      'photoUrlSnapshot': profile?.photoUrl,
      'invitedBy': invitedBy,
      if (includeJoinedAt) 'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  void _writeScheduleItems(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> tripRef,
    List<ScheduleItem> items,
  ) {
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      batch.set(
        tripRef.collection('itineraryItems').doc(_orderedId('item', index)),
        {
          'day': item.day,
          'time': item.time,
          'activity': item.activity,
          'type': _iconName(item.type),
          'cost': item.cost,
          'source': 'user',
          'order': index,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
  }

  void _writeBookings(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> tripRef,
    List<Booking> bookings,
  ) {
    for (var index = 0; index < bookings.length; index++) {
      final booking = bookings[index];
      batch.set(
        tripRef.collection('bookings').doc(_orderedId('booking', index)),
        {
          'title': booking.title,
          'date': booking.date,
          'time': booking.time,
          'reference': booking.reference,
          'cost': booking.cost,
          'type': _iconName(booking.icon),
          'attachmentPath': null,
          'order': index,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
  }

  void _writeBudgetCategories(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> tripRef,
    List<BudgetCategory> categories,
  ) {
    for (var index = 0; index < categories.length; index++) {
      final category = categories[index];
      batch.set(tripRef.collection('budgetCategories').doc(category.id), {
        'id': category.id,
        'category': category.category,
        'planned': category.planned,
        'actual': category.effectiveActual,
        'spendings': category.spendings
            .map((spending) => spending.toMap())
            .toList(),
        'order': index,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _removeAccountFromTrip(String accountId, String tripId) async {
    final tripRef = _sharedTripDoc(tripId);
    final trip = await tripRef.get();
    if (!trip.exists) {
      await _membershipsRef(accountId).doc(tripId).delete();
      return;
    }

    final data = trip.data() ?? const <String, dynamic>{};
    final memberIds = _stringList(data['memberIds'])
      ..removeWhere((memberId) => memberId == accountId);
    final roles = Map<String, String>.from(
      ((data['roles'] as Map?) ?? const <String, dynamic>{}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    )..remove(accountId);

    if (memberIds.isEmpty) {
      await _deleteTripTree(
        tripRef,
        allMemberIds: _stringList(data['memberIds']),
      );
      return;
    }

    var ownerId = (data['ownerId'] as String?) ?? accountId;
    if (ownerId == accountId) {
      ownerId = memberIds.first;
      roles[ownerId] = 'owner';
    }

    final batch = _firestore.batch();
    batch.update(tripRef, {
      'ownerId': ownerId,
      'memberIds': memberIds,
      'roles': roles,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(tripRef.collection('members').doc(accountId));
    batch.delete(_membershipsRef(accountId).doc(tripId));
    batch.set(_membershipsRef(ownerId).doc(tripId), {
      'tripId': tripId,
      'role': roles[ownerId] ?? 'owner',
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> _deleteTripTree(
    DocumentReference<Map<String, dynamic>> tripRef, {
    required List<String> allMemberIds,
  }) async {
    final childReferences = <DocumentReference<Map<String, dynamic>>>[];

    for (final collectionName in const [
      'itineraryItems',
      'bookings',
      'budgetCategories',
      'members',
      'invites',
      'aiRuns',
    ]) {
      final snapshot = await tripRef.collection(collectionName).get();
      childReferences.addAll(snapshot.docs.map((doc) => doc.reference));
    }

    final channels = await tripRef.collection('channels').get();
    for (final channel in channels.docs) {
      final messages = await channel.reference.collection('messages').get();
      childReferences.addAll(messages.docs.map((doc) => doc.reference));
      childReferences.add(channel.reference);
    }

    await _deleteReferences(childReferences);

    final rootReferences = <DocumentReference<Map<String, dynamic>>>[];
    for (final memberId in allMemberIds) {
      rootReferences.add(_membershipsRef(memberId).doc(tripRef.id));
    }
    rootReferences.add(tripRef);
    await _deleteReferences(rootReferences);
  }

  Future<void> _deleteReferences(
    List<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    for (var start = 0; start < references.length; start += 450) {
      final batch = _firestore.batch();
      for (final reference in references.skip(start).take(450)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }
}

Map<String, dynamic> _orderedDocData(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  return {'id': doc.id, ...doc.data()};
}

int _compareScheduleItems(ScheduleItem a, ScheduleItem b) {
  final dayCompare = a.day.compareTo(b.day);
  if (dayCompare != 0) return dayCompare;
  return a.time.compareTo(b.time);
}

int _compareBookings(Booking a, Booking b) {
  final dateCompare = a.date.compareTo(b.date);
  if (dateCompare != 0) return dateCompare;
  return a.time.compareTo(b.time);
}

String _orderedId(String prefix, int index) =>
    '$prefix-${index.toString().padLeft(4, '0')}';

List<String> _stringList(Object? value) =>
    ((value as List<dynamic>?) ?? const []).whereType<String>().toList();

int _timestampMillis(Object? value) {
  if (value is Timestamp) return value.millisecondsSinceEpoch;
  return 0;
}

bool _shouldArchiveExpiredTrip(Trip trip, DateTime now) {
  final endDate = _parseTripDate(trip.endDate);
  if (endDate == null) return false;
  final archiveDate = _dateOnly(endDate.add(const Duration(days: 1)));
  return !_dateOnly(now).isBefore(archiveDate);
}
