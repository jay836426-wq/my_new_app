import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),

      body: ListView(
        children: const [

          ListTile(
            leading: Icon(Icons.person, color: Colors.white),
            title: Text(
              'Account',
              style: TextStyle(color: Colors.white),
            ),
          ),

          ListTile(
            leading: Icon(Icons.palette, color: Colors.white),
            title: Text(
              'Appearance',
              style: TextStyle(color: Colors.white),
            ),
          ),

          ListTile(
            leading: Icon(Icons.help_outline, color: Colors.white),
            title: Text(
              'Support',
              style: TextStyle(color: Colors.white),
            ),
          ),

          ListTile(
            leading: Icon(Icons.logout, color: Colors.redAccent),
            title: Text(
              'Sign Out',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),

        ],
      ),
    );
  }
}