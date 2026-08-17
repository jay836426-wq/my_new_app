import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'main_navigation_screen.dart';
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
  final phoneController = TextEditingController();
  final codeController = TextEditingController();

  String? verificationId;

  bool emailVerified = false;
  bool codeSent = false;
  bool loading = false;

  Timer? emailCheckTimer;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    emailVerified = user?.emailVerified ?? false;

    if (!emailVerified) {
      _sendVerificationEmail();
      _startEmailVerificationCheck();
    }
  }

  @override
  void dispose() {
    emailCheckTimer?.cancel();
    phoneController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      await user.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification email sent to ${user.email}.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Could not send verification email.'),
        ),
      );
    }
  }

  void _startEmailVerificationCheck() {
    emailCheckTimer?.cancel();

    emailCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser?.emailVerified == true) {
        emailCheckTimer?.cancel();

        if (!mounted) return;

        setState(() {
          emailVerified = true;
        });
      }
    });
  }

  Future<void> sendSmsCode() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await user.reload();

    final refreshedUser = FirebaseAuth.instance.currentUser;

    if (refreshedUser == null || !refreshedUser.emailVerified) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verify your email before setting up SMS MFA.'),
        ),
      );

      return;
    }

    final phoneNumber = phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your phone number.')));

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final multiFactorSession = await refreshedUser.multiFactor.getSession();

      await FirebaseAuth.instance.verifyPhoneNumber(
        multiFactorSession: multiFactorSession,
        phoneNumber: phoneNumber,

        verificationCompleted: (_) {},

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() {
            loading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Phone verification failed.')),
          );
        },

        codeSent: (String verificationIdValue, int? resendToken) {
          if (!mounted) return;

          setState(() {
            verificationId = verificationIdValue;
            codeSent = true;
            loading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS verification code sent.')),
          );
        },

        codeAutoRetrievalTimeout: (String verificationIdValue) {
          verificationId = verificationIdValue;
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Unable to send SMS code.')),
      );
    }
  }

  Future<void> verifySmsCode() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || verificationId == null) return;

    final smsCode = codeController.text.trim();

    if (smsCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter the SMS code.')));

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: smsCode,
      );

      final assertion = PhoneMultiFactorGenerator.getAssertion(credential);

      await user.multiFactor.enroll(assertion, displayName: 'Primary Phone');

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => widget.isNewUser
              ? const TutorialScreen()
              : const MainNavigationScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Invalid verification code.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        title: const Text('Secure Your Account'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          children: [
            const SizedBox(height: 20),

            if (!emailVerified) ...[
              const Icon(Icons.email_outlined, color: Colors.white, size: 60),

              const SizedBox(height: 20),

              const Text(
                'Verify your email',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'We sent a verification link to ${widget.contactInfo}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _sendVerificationEmail,
                child: const Text('Resend Verification Email'),
              ),
            ],

            if (emailVerified && !codeSent) ...[
              const Text(
                'Set up SMS verification',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+1 555 555 5555',
                  labelStyle: TextStyle(color: Colors.white),
                  hintStyle: TextStyle(color: Colors.white38),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: loading ? null : sendSmsCode,
                child: Text(loading ? 'Sending...' : 'Send SMS Code'),
              ),
            ],

            if (codeSent) ...[
              const Text(
                'Enter verification code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  labelStyle: TextStyle(color: Colors.white),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: loading ? null : verifySmsCode,
                child: Text(loading ? 'Verifying...' : 'Verify'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
