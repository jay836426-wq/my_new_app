import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon! 🚀 We are working on this feature.'),
      ),
    );
  }

  /*Future<void> signOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', false);

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (route) => false,
    );
  }*/

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
        children: [

          ListTile(
            leading: Icon(Icons.person, color: Colors.white),
            title: Text(
              ' 👤 Account',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => showComingSoon(context),
          ),

          ListTile(
            leading: Icon(Icons.palette, color: Colors.white),
            title: Text(
              '🎨 Appearance',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => showComingSoon(context),
          ),

          ListTile(
            leading: Icon(Icons.help_outline, color: Colors.white),
            title: Text(
              '🛟 Support',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => showComingSoon(context),
          ),

          ListTile(
            leading: Icon(Icons.lock_outline, color: Colors.white),
            title: Text(
              '🔒 Privacy',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => showComingSoon(context),
          ),

          ListTile(
            leading: Icon(Icons.notifications_outlined, color: Colors.white),
            title: Text(
              '🔔 Notifications',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => showComingSoon(context),
          ),

          ListTile(
            leading: Icon(Icons.description_outlined, color: Colors.white),
            title: Text(
              '📜 Terms & Conditions',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => showComingSoon(context),
          ),

          SizedBox(height: 20),
          
          ListTile(
            leading: Icon(Icons.logout, color: Colors.redAccent),
            title: Text(
              '🚪 Sign Out',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () => showComingSoon(context),
          ),

          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.redAccent),
            title: Text(
              '🗑️ Delete Account',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () => showComingSoon(context),
          ),

          const SizedBox(height: 30),

          Center(
            child: Text(
              'Traqon v1.0',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}