import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:TrakOn/main.dart';
import 'notification_settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Signs the user out of Firebase while preserving locally saved app data.
  Future<void> signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('isLoggedIn', false);

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthChoiceScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to sign out. Please try again.')),
      );
    }
  }

  // Permanently deletes the Firebase account and all locally stored TrakOn data.
  Future<void> deleteAccount(BuildContext context) async {
    try {
      // Get the currently signed-in Firebase user.
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No signed-in user found.');
      }

      // Delete the user's Firebase Authentication account.
      await user.delete();

      // Only clear local TrakOn data after Firebase deletion succeeds.
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!context.mounted) return;

      // Return the user to the authentication screen
      // and remove all previous screens from navigation history.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthChoiceScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) return;

      String message = 'Unable to delete your account.';

      // Firebase may require the user to authenticate again
      // before allowing a sensitive account change.
      if (error.code == 'requires-recent-login') {
        message =
            'For security, please sign out and sign back in before deleting your account.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete your account. Please try again.'),
        ),
      );
    }
  }

  // Opens one of the Settings subpages.
  void openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('⚙️ Settings'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          const SettingsSectionTitle(title: 'GENERAL'),

          SettingsTile(
            icon: Icons.person,
            title: '👤 Account',
            onTap: () {
              openPage(context, const AccountSettingsScreen());
            },
          ),

          SettingsTile(
            icon: Icons.notifications_outlined,
            title: '🔔 Notifications',
            onTap: () {
              openPage(context, const NotificationSettingsScreen());
            },
          ),

          const SettingsDivider(),

          const SettingsSectionTitle(title: 'SUPPORT & INFORMATION'),

          SettingsTile(
            icon: Icons.help_outline,
            title: '🛟 Support',
            onTap: () {
              openPage(context, const SupportScreen());
            },
          ),

          SettingsTile(
            icon: Icons.lock_outline,
            title: '🔒 Privacy',
            onTap: () {
              openPage(context, const PrivacyScreen());
            },
          ),

          SettingsTile(
            icon: Icons.description_outlined,
            title: '📜 Terms & Conditions',
            onTap: () {
              openPage(context, const TermsScreen());
            },
          ),

          SettingsTile(
            icon: Icons.info_outline,
            title: 'ℹ️ About TrakOn',
            onTap: () {
              openPage(context, const AboutTrakOnScreen());
            },
          ),

          const SettingsDivider(),

          const SettingsSectionTitle(title: 'ACCOUNT ACTIONS'),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              '🚪 Sign Out',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () async {
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Are you sure you want to sign out?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext, false);
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext, true);
                        },
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true && context.mounted) {
                await signOut(context);
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text(
              '🗑️ Delete Account',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () async {
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Are you sure you want to delete your account?\n\n'
                      'This will permanently delete your TrakOn account, locally saved tasks, '
                      'preferences, streaks, and account information.\n\n'
                      'This action cannot be undone.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext, false);
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext, true);
                        },
                        child: const Text(
                          'Delete Account',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true && context.mounted) {
                await deleteAccount(context);
              }
            },
          ),

          const SizedBox(height: 30),

          const Center(
            child: Text(
              'TrakOn v1.0',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),

          const SizedBox(height: 8),

          const Center(
            child: Text(
              'Track. Focus. Achieve.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable tile used on the main Settings page.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// Reusable section heading used on the main Settings page.
class SettingsSectionTitle extends StatelessWidget {
  final String title;

  const SettingsSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// Reusable divider used between Settings sections.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(color: Colors.white12, indent: 16, endIndent: 16);
  }
}

// Reusable layout for informational Settings pages.
class SettingsInformationPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const SettingsInformationPage({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 38),
            ),
          ),

          const SizedBox(height: 24),

          ...children,
        ],
      ),
    );
  }
}

// Reusable heading used inside a Settings subpage.
class InformationHeading extends StatelessWidget {
  final String text;

  const InformationHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// Reusable paragraph used inside a Settings subpage.
class InformationParagraph extends StatelessWidget {
  final String text;

  const InformationParagraph(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }
}

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  String displayName = 'User';
  String email = 'Not available';

  String gender = 'Not set';
  String dateOfBirth = 'Not set';
  String phoneNumber = 'Not available';

  bool isLoading = true;

  int? get age {
    if (dateOfBirth == 'Not set') {
      return null;
    }

    try {
      final parts = dateOfBirth.split('/');

      if (parts.length != 3) {
        return null;
      }

      final birthDate = DateTime(
        int.parse(parts[2]),
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      final today = DateTime.now();

      int calculatedAge = today.year - birthDate.year;

      // If the birthday hasn't happened yet this year,
      // subtract one year from the age.
      final birthdayThisYear = DateTime(
        today.year,
        birthDate.month,
        birthDate.day,
      );

      if (today.isBefore(birthdayThisYear)) {
        calculatedAge--;
      }

      return calculatedAge;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    loadAccountInfo();
  }

  Future<void> loadAccountInfo() async {
    // Get the currently signed-in Firebase user.
    final user = FirebaseAuth.instance.currentUser;

    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      displayName =
          user?.displayName ??
          prefs.getString('fullName') ??
          prefs.getString('username') ??
          'User';

      email = user?.email ?? prefs.getString('email') ?? 'Not available';

      gender = prefs.getString('gender') ?? 'Not set';

      dateOfBirth = prefs.getString('dateOfBirth') ?? 'Not set';

      phoneNumber =
          user?.phoneNumber ??
          prefs.getString('phoneNumber') ??
          'Not available';
      isLoading = false;
    });
  }

  Future<void> showEditProfileDialog() async {
    final nameController = TextEditingController(
      text: displayName == 'User' ? '' : displayName,
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Edit Profile',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Display Name',
              labelStyle: TextStyle(color: Colors.white60),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.greenAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();

                if (name.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext, name);
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        );
      },
    );

    nameController.dispose();

    if (newName == null) {
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No signed-in user found.');
      }

      // Update the name stored in Firebase Authentication.
      await user.updateDisplayName(newName);

      // Keep the local display name in sync too.
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('fullName', newName);

      if (!mounted) return;

      setState(() {
        displayName = newName;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update profile.')),
      );
    }
  }

  Future<void> showGenderPicker() async {
    final selectedGender = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Select Gender',
            style: TextStyle(color: Colors.white),
          ),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, 'Male');
              },
              child: const Text('Male', style: TextStyle(color: Colors.white)),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, 'Female');
              },
              child: const Text(
                'Female',
                style: TextStyle(color: Colors.white),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, 'Non-binary');
              },
              child: const Text(
                'Non-binary',
                style: TextStyle(color: Colors.white),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext, 'Prefer not to say');
              },
              child: const Text(
                'Prefer not to say',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (selectedGender == null) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('gender', selectedGender);

    if (!mounted) return;

    setState(() {
      gender = selectedGender;
    });
  }

  Future<void> showDateOfBirthPicker() async {
    DateTime selectedDate = DateTime(2000, 1, 1);

    // If a birthday is already saved, start the picker there.
    if (dateOfBirth != 'Not set') {
      try {
        final parts = dateOfBirth.split('/');

        if (parts.length == 3) {
          selectedDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }
      } catch (_) {
        selectedDate = DateTime(2000, 1, 1);
      }
    }

    final bool? confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (popupContext) {
        return Container(
          height: 330,
          color: Colors.black,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Apple-style Month / Day / Year wheels
                Expanded(
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      brightness: Brightness.dark,
                      primaryColor: Colors.greenAccent,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: selectedDate,
                      minimumDate: DateTime(1900, 1, 1),
                      maximumDate: DateTime.now(),

                      // Prevent selecting a future birthday.
                      onDateTimeChanged: (newDate) {
                        selectedDate = newDate;
                      },
                    ),
                  ),
                ),

                // Small TrakOn-style Done button
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CupertinoButton(
                    color: Colors.greenAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 10,
                    ),
                    onPressed: () {
                      Navigator.pop(popupContext, true);
                    },
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final formattedDate =
        '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}';

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('dateOfBirth', formattedDate);

    if (!mounted) return;

    setState(() {
      dateOfBirth = formattedDate;
    });
  }

  Future<void> showEditEmailDialog() async {
    final emailController = TextEditingController(
      text: email == 'Not available' ? '' : email,
    );

    final newEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Change Email',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'New Email',
              labelStyle: TextStyle(color: Colors.white60),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.greenAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                final value = emailController.text.trim();

                if (value.isEmpty || !value.contains('@')) {
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        );
      },
    );

    emailController.dispose();

    if (newEmail == null || newEmail.toLowerCase() == email.toLowerCase()) {
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No signed-in user found.');
      }

      // Firebase sends a verification email to the new address.
      // The actual account email changes after verification.
      await user.verifyBeforeUpdateEmail(newEmail);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verification email sent to $newEmail. '
            'Your email will update after you verify it.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      String message = 'Unable to update email.';

      if (error.code == 'requires-recent-login') {
        message =
            'For security, please sign out and sign back in before changing your email.';
      } else if (error.code == 'email-already-in-use') {
        message =
            'That email address is already being used by another account.';
      } else if (error.code == 'invalid-email') {
        message = 'Enter a valid email address.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to update email.')));
    }
  }

  Future<void> showEditPhoneDialog() async {
    final phoneController = TextEditingController(
      text: phoneNumber == 'Not available' ? '' : phoneNumber,
    );

    final newPhone = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Change Phone Number',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: phoneController,
            autofocus: true,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '+1 555 123 4567',
              labelStyle: TextStyle(color: Colors.white60),
              hintStyle: TextStyle(color: Colors.white30),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.greenAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                String value = phoneController.text.trim();

                if (value.isEmpty) return;

                value = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

                // Assume US number if 10 digits are entered.
                if (RegExp(r'^\d{10}$').hasMatch(value)) {
                  value = '+1$value';
                } else if (RegExp(r'^1\d{10}$').hasMatch(value)) {
                  value = '+$value';
                }

                if (!value.startsWith('+')) {
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text(
                'Send Code',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        );
      },
    );

    phoneController.dispose();

    if (newPhone == null) return;

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: newPhone,

      verificationCompleted: (PhoneAuthCredential credential) async {
        await updatePhoneWithCredential(credential, newPhone);
      },

      verificationFailed: (FirebaseAuthException error) {
        if (!mounted) return;

        String message = 'Unable to verify phone number.';

        if (error.code == 'invalid-phone-number') {
          message = 'Enter a valid phone number.';
        } else if (error.code == 'too-many-requests') {
          message = 'Too many attempts. Try again later.';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },

      codeSent: (String verificationId, int? resendToken) async {
        if (!mounted) return;

        final smsCode = await showPhoneCodeDialog();

        if (smsCode == null) return;

        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );

        await updatePhoneWithCredential(credential, newPhone);
      },

      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<String?> showPhoneCodeDialog() async {
    final codeController = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Verify Phone Number',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: codeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              labelText: '6-digit code',
              labelStyle: TextStyle(color: Colors.white60),
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                final value = codeController.text.trim();

                if (value.length != 6) {
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text(
                'Verify',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        );
      },
    );

    codeController.dispose();

    return code;
  }

  Future<void> updatePhoneWithCredential(
    PhoneAuthCredential credential,
    String newPhone,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No signed-in user found.');
      }

      await user.updatePhoneNumber(credential);

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('phoneNumber', newPhone);

      if (!mounted) return;

      setState(() {
        phoneNumber = newPhone;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Phone number updated.')));
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      String message = 'Unable to update phone number.';

      if (error.code == 'requires-recent-login') {
        message =
            'For security, sign out and sign back in before changing your phone number.';
      } else if (error.code == 'credential-already-in-use') {
        message = 'That phone number is already connected to another account.';
      } else if (error.code == 'invalid-verification-code') {
        message = 'The verification code is incorrect.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('👤 Account'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 10),

                const CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.person, color: Colors.white, size: 38),
                ),

                const SizedBox(height: 18),

                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),

                const SizedBox(height: 32),

                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: Colors.greenAccent,
                  ),
                  title: const Text(
                    'Edit Profile',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: showEditProfileDialog,
                ),

                const SizedBox(height: 24),

                const Text(
                  'PERSONAL INFORMATION',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),

                const SizedBox(height: 8),

                ListTile(
                  leading: const Icon(
                    Icons.wc_outlined,
                    color: Colors.greenAccent,
                  ),
                  title: const Text(
                    'Gender',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Text(
                    gender,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  onTap: showGenderPicker,
                ),

                ListTile(
                  leading: const Icon(
                    Icons.cake_outlined,
                    color: Colors.greenAccent,
                  ),
                  title: const Text(
                    'Date of Birth',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Text(
                    dateOfBirth,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  onTap: showDateOfBirthPicker,
                ),

                ListTile(
                  leading: const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.greenAccent,
                  ),
                  title: const Text(
                    'Age',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Text(
                    age != null ? age.toString() : 'Not set',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'CONTACT INFORMATION',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),

                const SizedBox(height: 8),

                ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: Colors.greenAccent,
                  ),
                  title: const Text(
                    'Email',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: SizedBox(
                    width: 180,
                    child: Text(
                      email,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ),
                  onTap: showEditEmailDialog,
                ),

                ListTile(
                  leading: const Icon(
                    Icons.phone_outlined,
                    color: Colors.greenAccent,
                  ),
                  title: const Text(
                    'Phone Number',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: SizedBox(
                    width: 150,
                    child: Text(
                      phoneNumber,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ),
                  onTap: showEditPhoneDialog,
                ),
              ],
            ),
    );
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}='
              '${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
  }

  Future<void> openSupportEmail({
    required BuildContext context,
    required String subject,
    required String body,
  }) async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: 'jamaalbokhari045@gmail.com',
      query: encodeQueryParameters({'subject': subject, 'body': body}),
    );

    try {
      final launched = await launchUrl(emailUri);

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open your email app.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open your email app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsInformationPage(
      title: '🛟 Support',
      icon: Icons.help_outline,
      children: [
        const InformationHeading('Need Help?'),

        const InformationParagraph(
          'If you are having trouble with TrakOn, '
          'you can contact support, report a problem, '
          'or send feedback below.',
        ),

        const SizedBox(height: 24),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.bug_report_outlined,
            color: Colors.greenAccent,
          ),
          title: const Text(
            'Report an Issue',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Tell us about a bug or something that is not working.',
            style: TextStyle(color: Colors.white60),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () {
            openSupportEmail(
              context: context,
              subject: 'TrakOn Bug Report',
              body:
                  'Please describe the issue below:\n\n'
                  'What happened?\n\n'
                  'What did you expect to happen?\n\n'
                  'Steps to reproduce the issue:\n\n'
                  'Device / iPhone model:\n\n'
                  'iOS version:\n\n',
            );
          },
        ),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.support_agent, color: Colors.greenAccent),
          title: const Text(
            'Contact Support',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Get help with your TrakOn account or app experience.',
            style: TextStyle(color: Colors.white60),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () {
            openSupportEmail(
              context: context,
              subject: 'TrakOn Support',
              body:
                  'Hi TrakOn Support,\n\n'
                  'I need help with:\n\n',
            );
          },
        ),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.lightbulb_outline,
            color: Colors.greenAccent,
          ),
          title: const Text(
            'Send Feedback',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Share an idea or suggestion for improving TrakOn.',
            style: TextStyle(color: Colors.white60),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () {
            openSupportEmail(
              context: context,
              subject: 'TrakOn Feedback',
              body:
                  'Hi TrakOn,\n\n'
                  'Here is my feedback:\n\n',
            );
          },
        ),

        const SizedBox(height: 24),

        const InformationHeading('Before Reporting a Problem'),

        const InformationParagraph(
          'Make sure you are using the latest version of '
          'TrakOn and try restarting the app. For reminder '
          'issues, also confirm that notifications are enabled '
          'in both TrakOn and your device settings.',
        ),
      ],
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsInformationPage(
      title: '🔒 Privacy',
      icon: Icons.lock_outline,
      children: [
        InformationHeading('Your Information'),

        InformationParagraph(
          'TrakOn stores task information, streaks, preferences, and certain '
          'profile settings locally on your device. Account authentication '
          'information may also be processed through Firebase services.',
        ),

        SizedBox(height: 24),

        InformationHeading('Account Information'),

        InformationParagraph(
          'Information such as your email address, display name, and phone '
          'number may be associated with your TrakOn account to support sign-in, '
          'verification, and account management features.',
        ),

        SizedBox(height: 24),

        InformationHeading('Task Data'),

        InformationParagraph(
          'Your tasks, completion history, streak information, and notification '
          'preferences are currently stored locally on your device in Version 1.0.',
        ),

        SizedBox(height: 24),

        InformationHeading('Data Sharing'),

        InformationParagraph(
          'TrakOn does not sell your personal information. Third-party services '
          'used by TrakOn may process limited account information when necessary '
          'to provide authentication, verification, or notification-related '
          'features.',
        ),

        SizedBox(height: 24),

        InformationHeading('Deleting Your Data'),

        InformationParagraph(
          'You can delete your TrakOn account from Settings. Deleting your '
          'account removes the associated authentication account and clears '
          'locally stored TrakOn information from this device.',
        ),

        SizedBox(height: 24),

        InformationHeading('Privacy Updates'),

        InformationParagraph(
          'TrakOn privacy practices may be updated as new features and services '
          'are introduced. Any major changes will be reflected in future '
          'versions of this privacy information.',
        ),
      ],
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsInformationPage(
      title: '📜 Terms & Conditions',
      icon: Icons.description_outlined,
      children: [
        InformationHeading('Using TrakOn'),

        InformationParagraph(
          'By using TrakOn, you agree to use the application responsibly and '
          'in accordance with applicable laws and these terms.',
        ),

        SizedBox(height: 24),

        InformationHeading('Productivity Assistance'),

        InformationParagraph(
          'TrakOn is designed to help organize tasks, reminders, routines, and '
          'personal productivity. TrakOn does not guarantee that reminders or '
          'notifications will always be delivered at an exact time.',
        ),

        SizedBox(height: 24),

        InformationHeading('Important Responsibilities'),

        InformationParagraph(
          'Users remain responsible for reviewing important obligations and '
          'should not rely solely on TrakOn for urgent, medical, financial, '
          'legal, safety-related, or other time-sensitive responsibilities.',
        ),

        SizedBox(height: 24),

        InformationHeading('Account Responsibility'),

        InformationParagraph(
          'You are responsible for maintaining access to your TrakOn account '
          'and protecting your sign-in information. You should not share '
          'verification codes or account credentials with others.',
        ),

        SizedBox(height: 24),

        InformationHeading('App Availability'),

        InformationParagraph(
          'TrakOn may occasionally be unavailable, contain bugs, or behave '
          'unexpectedly. Features may be changed, improved, added, or removed '
          'as the application continues to develop.',
        ),

        SizedBox(height: 24),

        InformationHeading('Account Deletion'),

        InformationParagraph(
          'You may delete your TrakOn account through Settings. Account deletion '
          'is intended to permanently remove the associated authentication '
          'account and locally stored TrakOn information from the device.',
        ),

        SizedBox(height: 24),

        InformationHeading('Updates to These Terms'),

        InformationParagraph(
          'These terms may be updated as TrakOn evolves. Continued use of the '
          'application after future updates may be subject to revised terms.',
        ),
      ],
    );
  }
}

class AboutTrakOnScreen extends StatelessWidget {
  const AboutTrakOnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsInformationPage(
      title: 'ℹ️ About TrakOn',
      icon: Icons.track_changes,
      children: [
        // App name
        Center(
          child: Text(
            'TrakOn',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        SizedBox(height: 8),

        // TrakOn motto
        Center(
          child: Text(
            'Track. Focus. Achieve.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        SizedBox(height: 32),

        InformationHeading('About TrakOn'),

        InformationParagraph(
          'TrakOn is a productivity and task management app designed to help '
          'people organize their responsibilities, plan their days, stay '
          'focused, and make consistent progress toward their goals.',
        ),

        InformationParagraph(
          'Instead of making productivity complicated, TrakOn focuses on a '
          'simple daily experience where users can create tasks, plan ahead, '
          'set reminders, repeat important responsibilities, and keep track '
          'of what they accomplish.',
        ),

        SizedBox(height: 24),

        InformationHeading('What You Can Do'),

        InformationParagraph(
          'TrakOn allows you to organize daily tasks, schedule tasks for '
          'future dates, create recurring responsibilities, set reminder '
          'times, track completed tasks, view your schedule through the '
          'calendar, and monitor your consistency throughout the week.',
        ),

        InformationParagraph(
          'Tasks that are not completed can also remain part of your planning '
          'workflow, helping you stay aware of responsibilities that still '
          'need your attention.',
        ),

        SizedBox(height: 24),

        InformationHeading('The TrakOn Philosophy'),

        InformationParagraph(
          'Productivity does not have to mean filling every minute of the day '
          'or creating complicated systems. TrakOn is built around the idea '
          'that consistent progress comes from knowing what matters, staying '
          'focused, and continuing to move forward one task at a time.',
        ),

        InformationParagraph(
          'That idea is represented by the TrakOn motto: '
          '"Track. Focus. Achieve." Track what needs to be done, focus on '
          'what matters now, and achieve through consistency.',
        ),

        SizedBox(height: 24),

        InformationHeading('Why TrakOn Was Created'),

        InformationParagraph(
          'TrakOn began as a personal project with the goal of creating a '
          'productivity app that feels simple, motivating, and practical to '
          'use every day.',
        ),

        InformationParagraph(
          'The app continues to evolve through real-world use, testing, and '
          'feedback, with the goal of improving the experience while keeping '
          'the simplicity that TrakOn was built around.',
        ),

        SizedBox(height: 24),

        InformationHeading('Privacy & Control'),

        InformationParagraph(
          'TrakOn is designed to give users control over their experience. '
          'Task information, streaks, preferences, and other app data used '
          'by Version 1.0 are primarily stored locally on the device, while '
          'Firebase services are used for account authentication and related '
          'account features.',
        ),

        SizedBox(height: 24),

        InformationHeading('The Mission'),

        InformationParagraph(
          'The mission of TrakOn is to help people stay organized, build '
          'consistency, reduce the friction of daily planning, and make '
          'meaningful progress toward the responsibilities and goals that '
          'matter to them.',
        ),

        SizedBox(height: 24),

        InformationHeading('Created By'),

        InformationParagraph(
          'TrakOn was designed and developed by Jamaal Bokhari.',
        ),

        SizedBox(height: 24),

        InformationHeading('Version'),

        InformationParagraph(
          'TrakOn Version 1.0',
        ),

        SizedBox(height: 8),

        InformationParagraph(
          'This is the first public version of TrakOn. Future updates will '
          'continue to expand the app with new features, improvements, and '
          'ideas based on how people use TrakOn.',
        ),

        SizedBox(height: 32),

        Center(
          child: Text(
            'Track. Focus. Achieve.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        SizedBox(height: 30),
      ],
    );
  }
}
