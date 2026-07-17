import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:TrakOn/main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Signs the user out while preserving their locally saved app data.
  Future<void> signOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', false);

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthChoiceScreen(),
      ),
      (route) => false,
    );
  }

  // Deletes all locally stored TrakOn data.
  Future<void> deleteAccount(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthChoiceScreen(),
      ),
      (route) => false,
    );
  }

  // Opens one of the Settings subpages.
  void openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => page,
      ),
    );
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
              openPage(
                context,
                const AccountSettingsScreen(),
              );
            },
          ),

          SettingsTile(
            icon: Icons.notifications_outlined,
            title: '🔔 Notifications',
            onTap: () {
              openPage(
                context,
                const NotificationSettingsScreen(),
              );
            },
          ),

          const SettingsDivider(),

          const SettingsSectionTitle(
            title: 'SUPPORT & INFORMATION',
          ),

          SettingsTile(
            icon: Icons.help_outline,
            title: '🛟 Support',
            onTap: () {
              openPage(
                context,
                const SupportScreen(),
              );
            },
          ),

          SettingsTile(
            icon: Icons.lock_outline,
            title: '🔒 Privacy',
            onTap: () {
              openPage(
                context,
                const PrivacyScreen(),
              );
            },
          ),

          SettingsTile(
            icon: Icons.description_outlined,
            title: '📜 Terms & Conditions',
            onTap: () {
              openPage(
                context,
                const TermsScreen(),
              );
            },
          ),

          SettingsTile(
            icon: Icons.info_outline,
            title: 'ℹ️ About TrakOn',
            onTap: () {
              openPage(
                context,
                const AboutTrakOnScreen(),
              );
            },
          ),

          const SettingsDivider(),

          const SettingsSectionTitle(
            title: 'ACCOUNT ACTIONS',
          ),

          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.redAccent,
            ),
            title: const Text(
              '🚪 Sign Out',
              style: TextStyle(
                color: Colors.redAccent,
              ),
            ),
            onTap: () async {
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    content: const Text(
                      'Are you sure you want to sign out?',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(
                            dialogContext,
                            false,
                          );
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(
                            dialogContext,
                            true,
                          );
                        },
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.redAccent,
                          ),
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
            leading: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
            ),
            title: const Text(
              '🗑️ Delete Account',
              style: TextStyle(
                color: Colors.redAccent,
              ),
            ),
            onTap: () async {
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    content: const Text(
                      'Are you sure you want to delete your account?\n\n'
                      'This will permanently delete all locally saved tasks, '
                      'preferences, streaks, and account information.\n\n'
                      'This action cannot be undone.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(
                            dialogContext,
                            false,
                          );
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(
                            dialogContext,
                            true,
                          );
                        },
                        child: const Text(
                          'Delete Everything',
                          style: TextStyle(
                            color: Colors.redAccent,
                          ),
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
              'TrakOn v1.0 Beta',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Center(
            child: Text(
              'Track. Focus. Achieve.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
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
      leading: Icon(
        icon,
        color: Colors.white,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }
}

// Reusable section heading used on the main Settings page.
class SettingsSectionTitle extends StatelessWidget {
  final String title;

  const SettingsSectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        8,
      ),
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
    return const Divider(
      color: Colors.white12,
      indent: 16,
      endIndent: 16,
    );
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
              child: Icon(
                icon,
                color: Colors.white,
                size: 38,
              ),
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

  const InformationHeading(
    this.text, {
    super.key,
  });

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

  const InformationParagraph(
    this.text, {
    super.key,
  });

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

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsInformationPage(
      title: '👤 Account',
      icon: Icons.person,
      children: [
        InformationHeading('Your Account'),

        InformationParagraph(
          'Your TrakOn account information, tasks, streaks, and preferences '
          'are currently stored locally on this device.',
        ),

        SizedBox(height: 24),

        InformationHeading('Local Storage'),

        InformationParagraph(
          'Because Version 1.0 uses local storage, your information remains '
          'on the device where TrakOn is installed.',
        ),

        SizedBox(height: 24),

        InformationHeading('Account Management'),

        InformationParagraph(
          'You can sign out without deleting your tasks. Selecting Delete '
          'Account from the main Settings page permanently clears your saved '
          'TrakOn information.',
        ),
      ],
    );
  }
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsInformationPage(
      title: '🔔 Notifications',
      icon: Icons.notifications_outlined,
      children: [
        InformationHeading('Task Reminders'),

        InformationParagraph(
          'TrakOn reminders are designed to help you remember important tasks '
          'at the times you select.',
        ),

        SizedBox(height: 24),

        InformationHeading('Smart Reminder System'),

        InformationParagraph(
          'The Smart Reminder System is currently being completed for Version '
          '1.0. Notification controls will be added to this page once the '
          'system is fully connected and tested.',
        ),

        SizedBox(height: 24),

        InformationHeading('Coming Next'),

        InformationParagraph(
          'Future controls may include reminder preferences, repeated alerts '
          'for high-priority tasks, and notification permission management.',
        ),
      ],
    );
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsInformationPage(
      title: '🛟 Support',
      icon: Icons.help_outline,
      children: [
        InformationHeading('Need Help?'),

        InformationParagraph(
          'TrakOn is currently in beta testing. If you experience an issue, '
          'write down the steps you followed before the problem occurred.',
        ),

        SizedBox(height: 24),

        InformationHeading('Reporting a Bug'),

        InformationParagraph(
          'When reporting a problem, include the page you were using, the '
          'button you pressed, what you expected to happen, and what happened '
          'instead.',
        ),

        SizedBox(height: 24),

        InformationHeading('Helpful Details'),

        InformationParagraph(
          'Screenshots, error messages, and clear descriptions make it easier '
          'to identify and fix bugs quickly.',
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
          'TrakOn Version 1.0 stores your tasks, streaks, preferences, and '
          'basic account information locally on your device.',
        ),

        SizedBox(height: 24),

        InformationHeading('Data Sharing'),

        InformationParagraph(
          'TrakOn does not currently transmit your locally stored task '
          'information to an external TrakOn server.',
        ),

        SizedBox(height: 24),

        InformationHeading('Deleting Your Data'),

        InformationParagraph(
          'You can permanently erase locally stored TrakOn information by '
          'selecting Delete Account from the main Settings page.',
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
        InformationHeading('Beta Software'),

        InformationParagraph(
          'TrakOn Version 1.0 is currently beta software. Features may be '
          'changed, updated, expanded, or removed as development continues.',
        ),

        SizedBox(height: 24),

        InformationHeading('App Availability'),

        InformationParagraph(
          'The application may occasionally contain bugs or behave '
          'unexpectedly during testing.',
        ),

        SizedBox(height: 24),

        InformationHeading('User Responsibility'),

        InformationParagraph(
          'Users should review important tasks independently and should not '
          'rely solely on TrakOn reminders for urgent or time-sensitive '
          'responsibilities.',
        ),

        SizedBox(height: 24),

        InformationHeading('Feedback'),

        InformationParagraph(
          'Beta users are encouraged to report unexpected behavior and provide '
          'constructive feedback that can improve future versions.',
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
        Center(
          child: Text(
            'TrakOn',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        SizedBox(height: 8),

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

        InformationHeading('About the App'),

        InformationParagraph(
          'TrakOn is a productivity application designed to help users '
          'organize daily tasks, plan future responsibilities, track progress, '
          'build streaks, and remain consistent with their goals.',
        ),

        SizedBox(height: 24),

        InformationHeading('Why TrakOn Was Created'),

        InformationParagraph(
          'TrakOn began as a personal project built from the desire to create '
          'a simple, motivating, and practical productivity app that people '
          'could enjoy using every day.',
        ),

        SizedBox(height: 24),

        InformationHeading('Created By'),

        InformationParagraph(
          'TrakOn was designed and developed by Jamaal Bokhari.',
        ),

        SizedBox(height: 24),

        InformationHeading('The Mission'),

        InformationParagraph(
          'The goal of TrakOn is to help people remain focused, build better '
          'daily habits, and make consistent progress toward the things that '
          'matter most to them.',
        ),

        SizedBox(height: 24),

        InformationHeading('Version'),

        InformationParagraph(
          'Version 1.0 Beta',
        ),

        SizedBox(height: 30),
      ],
    );
  }
}