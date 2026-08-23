import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'tutorial_screen.dart';

class PhoneTermsAcceptanceScreen extends StatefulWidget {
  final String phoneNumber;
  final String password;
  final String firstName;
  final String lastName;
  final String username;
  final String dateOfBirth;

  const PhoneTermsAcceptanceScreen({
    super.key,
    required this.phoneNumber,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.dateOfBirth,
  });

  @override
  State<PhoneTermsAcceptanceScreen> createState() =>
      _PhoneTermsAcceptanceScreenState();
}

class _PhoneTermsAcceptanceScreenState
    extends State<PhoneTermsAcceptanceScreen> {
  bool loading = false;

  Future<void> acceptTerms() async {
    setState(() {
      loading = true;
    });

    try {
      final completeSignup = FirebaseFunctions.instance.httpsCallable(
        'completePhoneSignup',
      );

      await completeSignup.call({
        'password': widget.password,
        'firstName': widget.firstName,
        'lastName': widget.lastName,
        'username': widget.username,
        'dateOfBirth': widget.dateOfBirth,

        // Record Terms acceptance for phone-created accounts too.
        'termsAccepted': true,
        'termsVersion': '1.0',
      });

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const TutorialScreen()),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Unable to finish account setup.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> declineTerms() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Decline Terms?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'You must accept the Terms & Conditions to create a TrakOn account. '
            'Declining will cancel account creation.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Go Back',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Decline',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      loading = true;
    });

    try {
      final deleteAccount = FirebaseFunctions.instance.httpsCallable(
        'deleteTrakOnAccount',
      );

      await deleteAccount.call();

      // Clear the deleted Firebase session locally too.
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Unable to cancel account creation. Please try again.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to cancel account creation. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TrakOn Terms & Conditions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'Version 1.0',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),

                    SizedBox(height: 28),

                    _TermsHeading('Using TrakOn'),
                    _TermsText(
                      'By using TrakOn, you agree to use the application '
                      'responsibly and in accordance with applicable laws '
                      'and these terms.',
                    ),

                    _TermsHeading('Productivity Assistance'),
                    _TermsText(
                      'TrakOn is designed to help organize tasks, reminders, '
                      'routines, and personal productivity. TrakOn does not '
                      'guarantee that reminders or notifications will always '
                      'be delivered at an exact time.',
                    ),

                    _TermsHeading('Important Responsibilities'),
                    _TermsText(
                      'Users remain responsible for reviewing important '
                      'obligations and should not rely solely on TrakOn for '
                      'urgent, medical, financial, legal, safety-related, '
                      'or other time-sensitive responsibilities.',
                    ),

                    _TermsHeading('Account Responsibility'),
                    _TermsText(
                      'You are responsible for maintaining access to your '
                      'TrakOn account and protecting your sign-in information. '
                      'You should not share verification codes or account '
                      'credentials with others.',
                    ),

                    _TermsHeading('App Availability'),
                    _TermsText(
                      'TrakOn may occasionally be unavailable, contain bugs, '
                      'or behave unexpectedly. Features may be changed, '
                      'improved, added, or removed as the application evolves.',
                    ),

                    _TermsHeading('Account Deletion'),
                    _TermsText(
                      'You may delete your TrakOn account through Settings. '
                      'Account deletion permanently removes the associated '
                      'account information handled by TrakOn.',
                    ),

                    _TermsHeading('Updates to These Terms'),
                    _TermsText(
                      'These terms may be updated as TrakOn evolves. '
                      'Continued use after future updates may be subject '
                      'to revised terms.',
                    ),

                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.black,
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading ? null : declineTerms,
                      child: const Text('Decline'),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading ? null : acceptTerms,
                      child: Text(
                        loading ? 'Please wait...' : 'Accept & Continue',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsHeading extends StatelessWidget {
  final String text;

  const _TermsHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  final String text;

  const _TermsText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }
}
