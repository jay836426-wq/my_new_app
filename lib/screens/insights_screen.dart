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

  Widget statCard({required String label, required String value,
      required IconData icon, required Color color}) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF181B1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 14),
        Text(value, style: const TextStyle(color: Colors.white,
          fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    ));
  }

  Widget sectionHeading(String title, String detail) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: Colors.white,
        fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(detail, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final week = List.generate(7, (index) => weekStart.add(Duration(days: index)));
    final today = DateTime(now.year, now.month, now.day);
    final completedDates = tasksByDate.entries.where((entry) {
      final parts = entry.key.split('-').map(int.tryParse).toList();
      if (parts.length != 3 || parts.any((part) => part == null)) return false;
      return !DateTime(parts[0]!, parts[1]!, parts[2]!).isAfter(today);
    }).toList();
    final all = completedDates.expand((entry) => entry.value).toList();
    final done = all.where((task) => task['completed'] == true).length;
    final completedDays = completedDates.where((entry) => entry.value.isNotEmpty &&
        entry.value.every((task) => task['completed'] == true)).length;
    final rate = all.isEmpty ? 0 : (100 * done / all.length).round();
    final categories = <String, List<Map<String, dynamic>>>{};
    for (final task in all) {
      final category = task['category']?.toString() ?? 'Other';
      categories.putIfAbsent(category, () => []).add(task);
    }
    final categoryNames = categories.keys.toList()
      ..sort((a, b) => categories[b]!.length.compareTo(categories[a]!.length));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Goals & Stats'), backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh),
          tooltip: 'Refresh stats')]),
      body: loading ? const Center(child: CircularProgressIndicator()) :
        ListView(padding: const EdgeInsets.all(20), children: [
          sectionHeading('Your progress', 'Based on saved tasks through today'),
          const SizedBox(height: 16),
          Row(children: [
            statCard(label: 'Completion rate', value: '$rate%',
              icon: Icons.donut_large, color: Colors.greenAccent),
            const SizedBox(width: 12),
            statCard(label: 'Tasks done', value: '$done',
              icon: Icons.task_alt, color: Colors.lightBlueAccent),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            statCard(label: 'Day streak', value: '$streak',
              icon: Icons.local_fire_department, color: Colors.orangeAccent),
            const SizedBox(width: 12),
            statCard(label: 'Perfect days', value: '$completedDays',
              icon: Icons.calendar_month, color: Colors.purpleAccent),
          ]),
          const SizedBox(height: 8),
          Text('$done of ${all.length} saved task occurrences completed',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 30),
          sectionHeading('This week', 'Completed tasks / saved tasks each day'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
            decoration: BoxDecoration(color: const Color(0xFF181B1A),
              borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              for (var i = 0; i < 7; i++) Builder(builder: (context) {
                final day = tasksByDate[dateKey(week[i])] ?? [];
                final finished = day.where((task) => task['completed'] == true).length;
                final fraction = day.isEmpty ? 0.0 : finished / day.length;
                return Expanded(child: Column(children: [
                  Text(day.isEmpty ? '–' : '$finished/${day.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  const SizedBox(height: 8),
                  SizedBox(height: 76, width: 22, child: Stack(children: [
                    Container(decoration: BoxDecoration(color: Colors.white12,
                      borderRadius: BorderRadius.circular(8))),
                    Positioned(bottom: 0, left: 0, right: 0,
                      child: Container(height: 76 * fraction,
                        decoration: BoxDecoration(color: Colors.greenAccent,
                          borderRadius: BorderRadius.circular(8)))),
                  ])),
                  const SizedBox(height: 8),
                  Text(labels[i], style: TextStyle(fontSize: 10,
                    color: dateKey(week[i]) == dateKey(now)
                      ? Colors.greenAccent : Colors.white54)),
                ]));
              }),
            ]),
          ),
          const SizedBox(height: 30),
          sectionHeading('By category', 'Where your saved tasks are going'),
          const SizedBox(height: 14),
          if (categoryNames.isEmpty)
            const Text('Complete a few tasks to see your categories.',
              style: TextStyle(color: Colors.white54)),
          for (final name in categoryNames) Builder(builder: (context) {
            final categoryTasks = categories[name]!;
            final finished = categoryTasks.where((task) => task['completed'] == true).length;
            return Padding(padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(name, style: const TextStyle(color: Colors.white))),
                  Text('$finished/${categoryTasks.length}',
                    style: const TextStyle(color: Colors.white70)),
                ]),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: finished / categoryTasks.length,
                  minHeight: 7, color: Colors.greenAccent,
                  backgroundColor: Colors.white12),
              ]));
          }),
          const SizedBox(height: 22),
          Row(children: [
            const Expanded(child: Text('Goals', style: TextStyle(color: Colors.white,
              fontSize: 24, fontWeight: FontWeight.bold))),
            IconButton(onPressed: () => editGoal(),
              icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
              tooltip: 'Add goal'),
          ]),
          Text(goals.isEmpty ? 'Turn plans into completed tasks'
              : '${goals.where((goal) => completedForGoal(goal['id']) >= ((goal['target'] as num?)?.toInt() ?? 1)).length} of ${goals.length} targets reached',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          if (goals.isEmpty) const Text('Add a goal, then link tasks to it when creating or editing them.',
            style: TextStyle(color: Colors.white70)),
          for (final goal in goals) Builder(builder: (context) {
            final count = completedForGoal(goal['id']);
            final target = (goal['target'] as num?)?.toInt() ?? 1;
            return Card(color: const Color(0xFF181B1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: count >= target ? Colors.greenAccent : Colors.white12,
                child: Icon(count >= target ? Icons.check : Icons.flag_outlined,
                  color: count >= target ? Colors.black : Colors.greenAccent)),
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
