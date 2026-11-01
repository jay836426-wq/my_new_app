import '../services/account_planning_store.dart';
import 'package:flutter/material.dart';

import '../utils/planning_rules.dart';

class RecentlyDeletedScreen extends StatefulWidget {
  const RecentlyDeletedScreen({super.key});
  @override
  State<RecentlyDeletedScreen> createState() => _RecentlyDeletedScreenState();
}

class _RecentlyDeletedScreenState extends State<RecentlyDeletedScreen> {
  List<TaskData>? _entries;
  String? _busy;
  String? _error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final entries = await (await AccountPlanningStore.current()).listState(
        'deletedTasks',
      );
      if (mounted) {
        setState(() {
          _entries = entries.reversed.toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not load deleted tasks. Pull to retry.');
      }
    }
  }

  Future<void> act(TaskData entry, bool restore) async {
    if (_busy != null) return;
    if (!restore) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Permanently delete?'),
          content: const Text(
            'This removes the recovery copy. It cannot be restored afterward.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete forever'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = entry['id'].toString());
    try {
      final store = await AccountPlanningStore.current();
      if (restore) {
        await store.restoreDeleted(entry['id'].toString());
      } else {
        await store.permanentlyDelete(entry['id'].toString());
      }
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(restore ? 'Task restored' : 'Recovery copy removed'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not finish. Your recovery copy is kept.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recently Deleted')),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Deleted tasks stay here until you restore or permanently delete them. Deleting a recurring task stops its series from that date onward; past history is kept.',
          ),
          const SizedBox(height: 20),
          if (_error != null) Text(_error!),
          if (_entries == null && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (_entries?.isEmpty == true)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No deleted tasks.'),
            ),
          for (final entry in _entries ?? <TaskData>[])
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      (entry['task'] as Map)['title']?.toString() ?? 'Task',
                    ),
                    subtitle: Text('Original date: ${entry['date']}'),
                  ),
                  OverflowBar(
                    children: [
                      TextButton(
                        onPressed: _busy != null
                            ? null
                            : () => act(entry, false),
                        child: const Text('Delete forever'),
                      ),
                      TextButton(
                        onPressed: _busy != null
                            ? null
                            : () => act(entry, true),
                        child: const Text('Restore'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
