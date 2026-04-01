class ChatRemoteDataSource {
  Future<String> sendMessage(String text) async {
    await Future.delayed(const Duration(seconds: 1));
    return 'AI reply to: $text';
  }
}