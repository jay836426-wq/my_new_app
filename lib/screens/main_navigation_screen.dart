import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:TrakOn/screens/calendar_screen.dart';

import 'home_screen.dart';
import 'insights_screen.dart';
//import 'calendar_screen.dart';
import 'settings_screen.dart';
import 'whats_new_screen.dart';

// import 'friends_screen.dart';

// ---------------------------
// Main Navigation Screen
// ---------------------------
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int selectedIndex = 0;
  static const String _release = '1.1';
  late final String _whatsNewKey;
  bool _checkingWhatsNew = true;
  bool _showWhatsNew = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    _whatsNewKey = '${uid}_whatsNewSeen_$_release';
    _checkWhatsNew();
  }

  Future<void> _checkWhatsNew() async {
    bool seen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(_whatsNewKey) ?? false;
    } catch (error) {
      debugPrint('Could not load What’s New preference: $error');
    }
    if (!mounted) return;
    setState(() {
      _showWhatsNew = !seen;
      _checkingWhatsNew = false;
    });
  }

  Future<void> _finishWhatsNew() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setBool(_whatsNewKey, true);
    if (!saved) throw StateError('Could not save What’s New preference');
    if (!mounted) return;
    setState(() => _showWhatsNew = false);
  }

  final List<Widget> screens = const [
    HomeScreen(),
    CalendarScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  void onTabTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingWhatsNew) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }
    if (_showWhatsNew) {
      return WhatsNewScreen(onFinished: _finishWhatsNew);
    }
    return Scaffold(
      body: screens[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onTabTapped,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
