import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'terms_acceptance_screen.dart';

class EmailOtpScreen extends StatefulWidget {
  final String email;
  final String firstName;
  final String lastName;
  final String username;
  final String dateOfBirth;

  const EmailOtpScreen({
    super.key,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.dateOfBirth,
  });

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final codeController = TextEditingController();

  bool verifying = false;
  bool resending = false;

  Future<void> verifyCode() async {
    final code = codeController.text.trim();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit verification code.')),
      );
      return;
    }

    setState(() {
      verifying = true;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifyEmailOtp',
      );

      final result = await callable.call({'email': widget.email, 'code': code});

      if (result.data['success'] == true) {
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TermsAcceptanceScreen(
              email: widget.email,
              firstName: widget.firstName,
              lastName: widget.lastName,
              username: widget.username,
              dateOfBirth: widget.dateOfBirth,
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      String message = 'Unable to verify code.';

      if (e.code == 'permission-denied') {
        message = 'Incorrect verification code.';
      } else if (e.code == 'deadline-exceeded') {
        message = 'This code has expired. Request a new one.';
      } else if (e.code == 'resource-exhausted') {
        message = 'Too many incorrect attempts. Request a new code.';
      } else if (e.code == 'not-found') {
        message = 'No verification code was found. Request a new one.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          verifying = false;
        });
      }
    }
  }

  Future<void> resendCode() async {
    setState(() {
      resending = true;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendEmailOtp');

      await callable.call({'email': widget.email});

      if (!mounted) return;

      codeController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new verification code was sent.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Unable to resend verification code.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          resending = false;
        });
      }
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
        title: const Text('Verify'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  color: Colors.white,
                  size: 64,
                ),

                const SizedBox(height: 24),

                const Text(
                  'Enter verification code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'We sent a 6-digit code to\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),

                const SizedBox(height: 30),

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
                    labelStyle: TextStyle(color: Colors.white70),
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: verifying ? null : verifyCode,
                  child: Text(verifying ? 'Verifying...' : 'Verify'),
                ),

                TextButton(
                  onPressed: resending ? null : resendCode,
                  child: Text(
                    resending ? 'Sending...' : 'Resend Code',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
