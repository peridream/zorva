import 'package:flutter/material.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

class AuthScreen extends StatelessWidget {
  final bool isSignUp;
  const AuthScreen({super.key, this.isSignUp = true});

  @override
  Widget build(BuildContext context) {
    return isSignUp ? const SignUpScreen() : const SignInScreen();
  }
}
