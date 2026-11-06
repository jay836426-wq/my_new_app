import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/planning_store.dart';
import '../utils/planning_rules.dart';
import '../utils/mood_rules.dart';
import '../screens/mood_check_in_screen.dart';

class HomeMoodCard extends StatelessWidget {
  const HomeMoodCard({super.key, required this.store, required this.onChanged});
  final PlanningStore store;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    Map? today;
    bool failed = false;
    try {
      final raw = store.prefs.getString(store.key('moodEntriesV12'));
      if (raw != null) {
        today = (jsonDecode(raw) as Map)[dayKey(DateTime.now())] as Map?;
      }
    } catch (_) {
      failed = true;
    }
    final mood = today?['mood'];
    final valid = mood is int && mood >= 0 && mood < moodLabels.length;
    Future<void> open() async {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const MoodCheckInScreen()),
      );
      onChanged();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF10281F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TODAY’S MOOD',
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            valid
                ? '${moodFaces[mood]}  ${moodLabels[mood]}'
                : 'How are you feeling today?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            failed
                ? 'Could not read your check-in. Open history to retry.'
                : valid
                ? 'Your check-in is saved for today.'
                : 'Take a moment for yourself. Your check-in is optional.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: open,
                child: Text(valid ? 'Edit mood' : 'Check in'),
              ),
              TextButton(
                onPressed: open,
                child: const Text(
                  'View history',
                  style: TextStyle(color: Colors.greenAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
