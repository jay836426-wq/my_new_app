import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskSearchResult {
  const TaskSearchResult(this.date, this.notificationId, this.title);
  final String date;
  final Object? notificationId;
  final String title;
}

class TaskSearchScreen extends StatefulWidget {
  const TaskSearchScreen({super.key});

  @override
  State<TaskSearchScreen> createState() => _TaskSearchScreenState();
}

class _TaskSearchScreenState extends State<TaskSearchScreen> {
  final controller = TextEditingController();
  final results = <(String, Map<String, dynamic>)>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${FirebaseAuth.instance.currentUser!.uid}_';
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    final found = <(String, Map<String, dynamic>)>[];
    for (final key in prefs.getKeys()) {
      String? date;
      if (key == '${prefix}tasks') {
        date = today;
      } else if (key.startsWith('${prefix}tasks_')) {
        final suffix = key.substring('${prefix}tasks_'.length);
        if (suffix != today && RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(suffix)) {
          date = suffix;
        }
      }
      if (date == null) continue;
      try {
        for (final value in jsonDecode(prefs.getString(key)!) as List) {
          found.add((date, Map<String, dynamic>.from(value as Map)));
        }
      } catch (_) {}
    }
    found.sort((a, b) => b.$1.compareTo(a.$1));
    if (!mounted) return;
    setState(() {
      results..clear()..addAll(found);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim().toLowerCase();
    final matches = results.where((entry) {
      final task = entry.$2;
      return query.isEmpty || [task['title'], task['description'], task['category'],
        task['priority'], ...(task['tags'] is List ? task['tags'] as List : [])]
          .any((value) => value?.toString().toLowerCase().contains(query) == true);
    }).toList();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Search all tasks'),
        backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          controller: controller, autofocus: true,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
            hintText: 'Name, description, category, priority or tag'),
        )),
        Expanded(child: loading ? const Center(child: CircularProgressIndicator()) :
          matches.isEmpty ? const Center(child: Text('No matching saved tasks',
            style: TextStyle(color: Colors.white70))) :
          ListView.builder(itemCount: matches.length, itemBuilder: (context, index) {
            final (date, task) = matches[index];
            return ListTile(
              title: Text(task['title']?.toString() ?? 'Task',
                style: const TextStyle(color: Colors.white)),
              subtitle: Text('$date  •  ${task['category'] ?? 'Personal'}',
                style: const TextStyle(color: Colors.white70)),
              trailing: task['completed'] == true
                ? const Icon(Icons.check_circle, color: Colors.greenAccent) : null,
              onTap: () => Navigator.pop(context, TaskSearchResult(
                date, task['notificationId'], task['title']?.toString() ?? '')),
            );
          })),
      ]),
    );
  }
}
