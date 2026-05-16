class LoginUser {
  String execute(String email, String password) {
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Please enter your email and password.';
    }

    return 'Login placeholder for $email';
  }
}
