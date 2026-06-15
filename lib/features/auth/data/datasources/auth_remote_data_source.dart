class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));

    return {'id': 'local-user', 'email': email};
  }
}
