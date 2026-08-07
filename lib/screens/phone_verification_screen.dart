import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'tutorial_screen.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const PhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState
    extends State<PhoneVerificationScreen> {
  final codeController = TextEditingController();

  ConfirmationResult? confirmationResult;

  bool sendingCode = false;
  bool codeSent = false;
  bool verifying = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      sendCode();
    });
  }

  Future<void> sendCode() async {
    setState(() {
      sendingCode = true;
    });

    try {
      final result =
          await FirebaseAuth.instance.signInWithPhoneNumber(
        widget.phoneNumber,
      );

      if (!mounted) return;

      setState(() {
        confirmationResult = result;
        codeSent = true;
        sendingCode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code sent.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        sendingCode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Could not send verification code.',
          ),
        ),
      );
    }
  }

  Future<void> verifyCode() async {
    final code = codeController.text.trim();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the 6-digit verification code.'),
        ),
      );
      return;
    }

    if (confirmationResult == null) return;

    setState(() {
      verifying = true;
    });

    try {
      await confirmationResult!.confirm(code);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const TutorialScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        verifying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Incorrect verification code.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Verify Phone'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.sms_outlined,
                  color: Colors.white,
                  size: 64,
                ),

                const SizedBox(height: 24),

                const Text(
                  'Verify your phone',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  codeSent
                      ? 'Enter the verification code sent to\n${widget.phoneNumber}'
                      : 'Sending a verification code to\n${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 30),

                if (codeSent)
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      letterSpacing: 8,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Verification Code',
                      labelStyle: TextStyle(
                        color: Colors.white70,
                      ),
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white38,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                if (codeSent)
                  const SizedBox(height: 20),

                if (codeSent)
                  ElevatedButton(
                    onPressed:
                        verifying ? null : verifyCode,
                    child: Text(
                      verifying
                          ? 'Verifying...'
                          : 'Verify',
                    ),
                  ),

                if (codeSent)
                  TextButton(
                    onPressed:
                        sendingCode ? null : sendCode,
                    child: const Text(
                      'Resend Code',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ),

                if (!codeSent && sendingCode)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}