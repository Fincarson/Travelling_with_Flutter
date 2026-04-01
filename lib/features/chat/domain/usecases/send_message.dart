class SendMessage {
  Future<String> execute(String text) async {
    if (text.trim().isEmpty) {
      return 'Message cannot be empty';
    }

    return 'Sending: $text';
  }
}