import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/account_planning_store.dart';
import '../services/planning_store.dart';
import '../utils/planning_rules.dart';

class MoodCheckInScreen extends StatefulWidget {
  const MoodCheckInScreen({super.key});
  @override
  State<MoodCheckInScreen> createState() => _MoodCheckInScreenState();
}

class _MoodCheckInScreenState extends State<MoodCheckInScreen> {
  PlanningStore? _store;
  Map<String, dynamic> _entries = {};
  int? _mood;
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;
  static const labels = ['Very low', 'Low', 'Okay', 'Good', 'Great'];
  static const faces = ['😞', '🙁', '😐', '🙂', '😄'];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final s = await AccountPlanningStore.current();
      final raw = s.prefs.getString(s.key('moodEntriesV12'));
      final entries = raw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final today = entries[dayKey(DateTime.now())] as Map?;
      if (mounted) {
        setState(() {
          _store = s;
          _entries = entries;
          _mood = today?['mood'] as int?;
          _note.text = today?['note']?.toString() ?? '';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load mood history.');
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (_mood == null) return;
    setState(() => _saving = true);
    try {
      final key = dayKey(DateTime.now());
      final updated = {
        ..._entries,
        key: {
          'mood': _mood,
          'note': _note.text.trim(),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      };
      if (!await _store!.prefs.setString(
        _store!.key('moodEntriesV12'),
        jsonEncode(updated),
      )) {
        throw StateError('Save failed');
      }
      if (mounted) {
        setState(() => _entries = updated);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Today’s mood saved')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> remove(String date) async {
    setState(() => _saving = true);
    try {
      final updated = Map<String, dynamic>.from(_entries)..remove(date);
      if (!await _store!.prefs.setString(
        _store!.key('moodEntriesV12'),
        jsonEncode(updated),
      )) {
        throw StateError('Delete failed');
      }
      if (mounted) setState(() => _entries = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates = _entries.keys.toList()
      ..sort((a, b) => parseDay(b).compareTo(parseDay(a)));
    return Scaffold(
      appBar: AppBar(title: const Text('Mood check-in')),
      body: _store == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'How are you feeling today?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Optional reflection, stored only on this device for this account. It does not affect your tasks or streak.',
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < 5; i++)
                      ChoiceChip(
                        label: Text('${faces[i]} ${labels[i]}'),
                        selected: _mood == i,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _mood = i),
                      ),
                  ],
                ),
                TextField(
                  controller: _note,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Optional note'),
                ),
                FilledButton(
                  onPressed: _saving || _mood == null ? null : save,
                  child: Text(_saving ? 'Saving…' : 'Save today’s mood'),
                ),
                const SizedBox(height: 24),
                const Text('Your history', style: TextStyle(fontSize: 20)),
                if (dates.isEmpty) const Text('No check-ins yet.'),
                for (final date in dates)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '$date • ${labels[(_entries[date]['mood'] as int).clamp(0, 4)]}',
                    ),
                    subtitle: Text(_entries[date]['note']?.toString() ?? ''),
                    trailing: IconButton(
                      tooltip: 'Delete check-in',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _saving ? null : () => remove(date),
                    ),
                  ),
              ],
            ),
    );
  }
}
