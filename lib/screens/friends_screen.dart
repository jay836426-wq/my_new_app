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
            'Friends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 12),

          Text(
            'See how your friends are staying consistent.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),

          SizedBox(height: 24),

          ListTile(
            leading: CircleAvatar(
              child: Text('A'),
            ),
            title: Text(
              'Alex',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '🔥 5 day streak',
              style: TextStyle(color: Colors.white70),
            ),
          ),

          ListTile(
            leading: CircleAvatar(
              child: Text('M'),
            ),
            title: Text(
              'Maya',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Completed 4 tasks today',
              style: TextStyle(color: Colors.white70),
            ),
          ),

          ListTile(
            leading: CircleAvatar(
              child: Text('J'),
            ),
            title: Text(
              'Jordan',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '🔥 2 day streak',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          SizedBox(height:30),

          ListTile(
            title: Text('Jordan'),
          ),

          SizedBox(height: 30),

          Text(
            'Recent Activity',
          ),

          ListTile(
            title: Text('Alex completed all daily tasks',
            style: TextStyle(color: Colors.white),
          )),

          ListTile(
            title: Text('Maya reached a 7 day streak',
            style: TextStyle(color: Colors.white),
          )),

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