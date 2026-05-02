import 'package:flutter/material.dart';

// ---------------------------
// MFA Success Screen
// ---------------------------
class MfaSuccessScreen extends StatelessWidget {
  const MfaSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Success'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'You are verified!',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}