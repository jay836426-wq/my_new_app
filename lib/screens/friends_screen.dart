import 'package:flutter/material.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Friends feature coming soon 🚀',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 12),

          SizedBox(height: 30),

          ElevatedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.person_add),
            label: Text('Invite More Friends'),
          ),
        ],
      ),
    );
  }
}
