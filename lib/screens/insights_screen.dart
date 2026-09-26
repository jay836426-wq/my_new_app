import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<Map<String, dynamic>> goals = [];
  final Map<String, List<Map<String, dynamic>>> tasksByDate = {};
  int streak = 0;
  bool loading = true;

  String get prefix => '${FirebaseAuth.instance.currentUser!.uid}_';
  String dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final today = dateKey(DateTime.now());
    final dates = <String, List<Map<String, dynamic>>>{};
    for (final key in prefs.getKeys()) {
      String? date;
      if (key == '${prefix}tasks') {
        date = today;
      } else if (key.startsWith('${prefix}tasks_')) {
        final suffix = key.substring('${prefix}tasks_'.length);
        if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(suffix) && suffix != today) {
          date = suffix;
        }
      }
      if (date == null) continue;
      try {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        dates[date] = (jsonDecode(raw) as List)
            .map((task) => Map<String, dynamic>.from(task as Map)).toList();
      } catch (_) {
        // Ignore invalid legacy entries without losing other days.
      }
    }

    var loadedGoals = <Map<String, dynamic>>[];
    try {
      final saved = prefs.getString('${prefix}goals');
      if (saved != null) {
        loadedGoals = (jsonDecode(saved) as List)
            .map((goal) => Map<String, dynamic>.from(goal as Map)).toList();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      tasksByDate..clear()..addAll(dates);
      goals = loadedGoals;
      streak = prefs.getInt('${prefix}streakCounter') ?? 0;
      loading = false;
    });
  }

  Future<void> saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${prefix}goals', jsonEncode(goals));
  }

  Future<void> editGoal([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: existing?['title']?.toString() ?? '');
    final target = TextEditingController(text: existing?['target']?.toString() ?? '5');
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'New goal' : 'Edit goal'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, maxLength: 100,
            decoration: const InputDecoration(labelText: 'Goal name')),
          TextField(controller: target, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of tasks to complete')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () {
            final count = int.tryParse(target.text.trim());
            if (name.text.trim().isEmpty || count == null || count < 1 || count > 9999) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Enter a name and a target from 1 to 9999.')));
              return;
            }
            Navigator.pop(dialogContext, (name.text.trim(), count));
          }, child: const Text('Save')),
        ],
      ),
    );
    name.dispose();
    target.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (existing == null) {
        goals.add({'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'title': result.$1, 'target': result.$2});
      } else {
        existing['title'] = result.$1;
        existing['target'] = result.$2;
      }
    });
    await saveGoals();
  }

  Future<void> deleteGoal(Map<String, dynamic> goal) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete goal?'),
        content: const Text('Existing tasks will remain, but their goal link will no longer be shown.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    setState(() => goals.remove(goal));
    await saveGoals();
  }

  int completedForGoal(Object? id) => tasksByDate.values
      .expand((tasks) => tasks)
      .where((task) => task['goalId'] == id && task['completed'] == true).length;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final week = List.generate(7, (index) => weekStart.add(Duration(days: index)));
    final all = tasksByDate.values.expand((tasks) => tasks).toList();
    final done = all.where((task) => task['completed'] == true).length;
    final completedDays = tasksByDate.values.where((day) => day.isNotEmpty &&
        day.every((task) => task['completed'] == true)).length;
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Goals & Stats'), backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh),
          tooltip: 'Refresh stats')]),
      body: loading ? const Center(child: CircularProgressIndicator()) :
        ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Your progress', style: TextStyle(color: Colors.white,
            fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: all.isEmpty ? 0 : done / all.length,
            color: Colors.greenAccent),
          const SizedBox(height: 12),
          Text('$done of ${all.length} saved tasks completed',
            style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Text('$completedDays fully completed days  •  $streak day streak',
            style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 28),
          const Text('This week', style: TextStyle(color: Colors.white,
            fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [for (var i = 0; i < 7; i++) Expanded(child: Column(children: [
            Text(labels[i], style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            CircularProgressIndicator(
              value: tasksByDate[dateKey(week[i])]?.isNotEmpty == true
                  ? tasksByDate[dateKey(week[i])]!.where((task) => task['completed'] == true).length /
                    tasksByDate[dateKey(week[i])]!.length : 0,
              color: Colors.greenAccent, backgroundColor: Colors.white24,
            ),
          ]))]),
          const SizedBox(height: 32),
          Row(children: [
            const Expanded(child: Text('Goals', style: TextStyle(color: Colors.white,
              fontSize: 24, fontWeight: FontWeight.bold))),
            IconButton(onPressed: () => editGoal(),
              icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
              tooltip: 'Add goal'),
          ]),
          if (goals.isEmpty) const Text('Add a goal, then link tasks to it when creating or editing them.',
            style: TextStyle(color: Colors.white70)),
          for (final goal in goals) Builder(builder: (context) {
            final count = completedForGoal(goal['id']);
            final target = (goal['target'] as num?)?.toInt() ?? 1;
            return Card(color: Colors.white10, child: ListTile(
              title: Text(goal['title']?.toString() ?? 'Goal',
                style: const TextStyle(color: Colors.white)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$count of $target linked tasks completed',
                  style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: (count / target).clamp(0.0, 1.0).toDouble(),
                  color: Colors.greenAccent),
              ]),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                onSelected: (action) => action == 'edit' ? editGoal(goal) : deleteGoal(goal),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ));
          }),
        ]),
    );
  }
}
