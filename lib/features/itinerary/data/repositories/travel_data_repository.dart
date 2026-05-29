part of travel_agent_app;

class TravelDataRepository {
  const TravelDataRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String accountId) =>
      _firestore.collection('travel_users').doc(accountId);

  CollectionReference<Map<String, dynamic>> _tripsRef(String accountId) =>
      _userDoc(accountId).collection('trips');

  Future<UserProfile?> loadUser(String accountId) async {
    final snapshot = await _userDoc(accountId).get();
    if (!snapshot.exists) return null;
    return UserProfile.fromMap(snapshot.data() ?? const <String, dynamic>{});
  }

  Future<void> saveUser(String accountId, UserProfile profile) =>
      _userDoc(accountId).set(profile.toMap(), SetOptions(merge: true));

  Future<List<Trip>> loadTrips(String accountId) async {
    final snapshot = await _tripsRef(accountId).orderBy('updatedAt').get();
    final trips = snapshot.docs.map(Trip.fromDoc).toList();
    return trips.reversed.toList();
  }

  Future<void> saveTrip(String accountId, Trip trip) => _tripsRef(
    accountId,
  ).doc(trip.id).set(trip.toMap(), SetOptions(merge: true));

  Future<void> deleteUserData(String accountId) async {
    final trips = await _tripsRef(accountId).get();
    final batch = _firestore.batch();
    for (final trip in trips.docs) {
      batch.delete(trip.reference);
    }
    batch.delete(_userDoc(accountId));
    await batch.commit();
  }
}
