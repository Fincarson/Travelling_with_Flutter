import 'package:flutter/material.dart';

import '../../../../shared/widgets/responsive_page.dart';
import '../../domain/usecases/login_user.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String result = '';

  void login() {
    final useCase = LoginUser();
    final message = useCase.execute(
      emailController.text,
      passwordController.text,
    );

    setState(() {
      result = message;
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: ResponsivePage(
        maxContentWidth: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: login, child: const Text('Login')),
              const SizedBox(height: 16),
              Text(result),
            ],
          ),
        ),
      ),
    );
  }
}
