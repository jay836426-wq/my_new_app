import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'main_navigation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tutorial_screen.dart';


// ---------------------------
// MFA Screen
// ---------------------------
class MfaScreen extends StatefulWidget {
  final bool isNewUser;
  final String contactInfo;

  const MfaScreen({
    super.key,
    required this.contactInfo,
    required this.isNewUser,
  });

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  // TEMP: print code to console instead of showing it
  @override
  void initState() {
    super.initState();
    generateNewCode();
    print("MFA CODE: $generatedCode"); 
    startCountdown();
  }
  final TextEditingController codeController = TextEditingController();

  late String generatedCode;
  Timer? countdownTimer;
  int secondsRemaining = 60;
  bool codeExpired = false;

  @override
  void dispose() {
    countdownTimer?.cancel();
    codeController.dispose();
    super.dispose();
  }

  void generateNewCode() {
    final random = Random();
    generatedCode = (10000 + random.nextInt(90000)).toString();
  }

  void startCountdown() {
    countdownTimer?.cancel();

    setState(() {
      secondsRemaining = 60;
      codeExpired = false;
    });

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining > 1) {
        setState(() {
          secondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          secondsRemaining = 0;
          codeExpired = true;
        });
      }
    });
  }

  Future<void> verifyCode() async {
    final enteredCode = codeController.text.trim();

    if (codeExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code expired!')),
      );
      return;
    }

    if (enteredCode == generatedCode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => widget.isNewUser
          ? const TutorialScreen()
          : const MainNavigationScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect code. Please try again.')),
      );
    }
  }

  void resendCode() {
    generateNewCode();
    codeController.clear();
    startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Verify'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            TextField(
              controller: codeController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Enter code',
                labelStyle: TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: verifyCode,
              child: const Text('Verify'),
            ),

            ElevatedButton(
              onPressed: resendCode,
              child: const Text('Resend'),
            ),
          ],
        ),
      ),
    );
  }
}