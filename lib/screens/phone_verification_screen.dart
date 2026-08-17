import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'phone_terms_acceptance_screen.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String password;
  final String firstName;
  final String lastName;
  final String username;
  final String dateOfBirth;

  const PhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.dateOfBirth,
  });

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final codeController = TextEditingController();

  ConfirmationResult? confirmationResult;
  String? verificationId;

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
    if (!mounted) return;

    setState(() {
      sendingCode = true;
    });

    if (kIsWeb) {
      await _sendCodeWeb();
    } else {
      await _sendCodeNative();
    }
  }

  Future<void> _sendCodeWeb() async {
    try {
      final result = await FirebaseAuth.instance.signInWithPhoneNumber(
        widget.phoneNumber,
      );

      if (!mounted) return;

      setState(() {
        confirmationResult = result;
        codeSent = true;
        sendingCode = false;
      });

      _showMessage('Verification code sent.');
    } on FirebaseAuthException catch (e) {
      _handleSendError(e);
    }
  }

  Future<void> _sendCodeNative() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,

      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);

          await _completePhoneSignup(userCredential);
        } on FirebaseAuthException catch (e) {
          _showMessage(e.message ?? 'Automatic verification failed.');
        } on FirebaseFunctionsException catch (e) {
          _showMessage(e.message ?? 'Unable to complete phone signup.');
        } catch (e) {
          _showMessage('Something went wrong. Please try again.');
        }
      },

      verificationFailed: (FirebaseAuthException e) {
        _handleSendError(e);
      },

      codeSent: (String verificationIdValue, int? resendToken) {
        if (!mounted) return;

        setState(() {
          verificationId = verificationIdValue;
          codeSent = true;
          sendingCode = false;
        });

        _showMessage('Verification code sent.');
      },

      codeAutoRetrievalTimeout: (String verificationIdValue) {
        verificationId = verificationIdValue;
      },
    );
  }

  Future<void> verifyCode() async {
    final code = codeController.text.trim();

    if (code.length != 6) {
      _showMessage('Enter the 6-digit verification code.');
      return;
    }

    setState(() {
      verifying = true;
    });

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        if (confirmationResult == null) {
          throw FirebaseAuthException(
            code: 'missing-verification',
            message: 'Verification session missing. Resend the code.',
          );
        }

        userCredential = await confirmationResult!.confirm(code);
      } else {
        if (verificationId == null) {
          throw FirebaseAuthException(
            code: 'missing-verification',
            message: 'Verification session missing. Resend the code.',
          );
        }

        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId!,
          smsCode: code,
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }

      await _completePhoneSignup(userCredential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        verifying = false;
      });

      String message = e.message ?? 'Unable to verify code.';

      if (e.code == 'invalid-verification-code') {
        message = 'Incorrect verification code.';
      } else if (e.code == 'session-expired') {
        message = 'This code expired. Please resend it.';
      }

      _showMessage(message);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      setState(() {
        verifying = false;
      });

      _showMessage(e.message ?? 'Unable to complete signup.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        verifying = false;
      });

      _showMessage('Something went wrong. Please try again.');
    }
  }

  Future<void> _completePhoneSignup(UserCredential userCredential) async {
    if (userCredential.user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Phone account could not be created.',
      );
    }

    if (!mounted) return;

    // Phone verification succeeded.
    // Do not finalize the TrakOn account until the user accepts the Terms.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PhoneTermsAcceptanceScreen(
          phoneNumber: widget.phoneNumber,
          password: widget.password,
          firstName: widget.firstName,
          lastName: widget.lastName,
          username: widget.username,
          dateOfBirth: widget.dateOfBirth,
        ),
      ),
    );
  }

  void _handleSendError(FirebaseAuthException e) {
    if (!mounted) return;

    setState(() {
      sendingCode = false;
    });

    String message = e.message ?? 'Could not send verification code.';

    if (e.code == 'invalid-phone-number') {
      message = 'Please enter a valid phone number.';
    } else if (e.code == 'too-many-requests') {
      message = 'Too many attempts. Please try again later.';
    } else if (e.code == 'quota-exceeded') {
      message = 'SMS verification limit reached.';
    }

    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.sms_outlined, color: Colors.white, size: 64),

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
                      ? 'Enter the 6-digit code sent to\n${widget.phoneNumber}'
                      : 'Sending a verification code to\n${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
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

                if (codeSent) const SizedBox(height: 20),

                if (codeSent)
                  ElevatedButton(
                    onPressed: verifying ? null : verifyCode,
                    child: Text(verifying ? 'Verifying...' : 'Verify'),
                  ),

                if (codeSent)
                  TextButton(
                    onPressed: sendingCode ? null : sendCode,
                    child: Text(
                      sendingCode ? 'Sending...' : 'Resend Code',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),

                if (!codeSent && sendingCode)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
