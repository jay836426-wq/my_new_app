import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../services/account_planning_store.dart';
import '../services/planning_store.dart';
import '../services/check_in_service.dart';
import 'notification_service.dart';
import 'notification_settings_screen.dart';

class CheckInSettingsScreen extends StatefulWidget {
  const CheckInSettingsScreen({super.key});
  @override
  State<CheckInSettingsScreen> createState() => _CheckInSettingsScreenState();
}

class _CheckInSettingsScreenState extends State<CheckInSettingsScreen> {
  PlanningStore? _store;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final s = await AccountPlanningStore.current();
      if (mounted) setState(() => _store = s);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load settings.');
    }
  }

  Future<void> change(String name, bool value) async {
    setState(() => _busy = true);
    try {
      if (!await _store!.prefs.setBool(_store!.key(name), value)) {
        throw StateError('Save failed');
      }
      if (value && name != 'v12_moodPrompt') {
        final allowed = await NotificationService.requestPermissions();
        if (!allowed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Saved. Enable notification permission in iPhone Settings to receive alerts.',
              ),
            ),
          );
        }
      }
      await CheckInService.apply(_store!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not apply alerts. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> time(String type) async {
    final store = _store!;
    final name = CheckInService.pref(type);
    final initial = TimeOfDay(
      hour:
          store.prefs.getInt(store.key('${name}Hour')) ??
          (type == 'planning' ? 9 : 18),
      minute: store.prefs.getInt(store.key('${name}Minute')) ?? 0,
    );
    TimeOfDay? selected;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      var pending = initial;
      selected = await showCupertinoModalPopup<TimeOfDay>(
        context: context,
        builder: (sheetContext) => CupertinoTheme(
          data: CupertinoThemeData(brightness: Theme.of(context).brightness),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel'),
                      ),
                      CupertinoButton(
                        onPressed: () => Navigator.pop(sheetContext, pending),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 216,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: MediaQuery.of(context)
                          .alwaysUse24HourFormat,
                      initialDateTime: DateTime(
                        2026,
                        1,
                        1,
                        initial.hour,
                        initial.minute,
                      ),
                      onDateTimeChanged: (d) =>
                          pending = TimeOfDay(hour: d.hour, minute: d.minute),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      selected = await showTimePicker(context: context, initialTime: initial);
    }
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (!await store.prefs.setInt(store.key('${name}Hour'), selected.hour) ||
          !await store.prefs.setInt(
            store.key('${name}Minute'),
            selected.minute,
          )) {
        throw StateError('Save failed');
      }
      await CheckInService.apply(store);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reschedule. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _store;
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders & check-ins')),
      body: s == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!),
            )
          : ListView(
              children: [
                ListTile(
                  title: const Text('Task reminders & master switch'),
                  subtitle: const Text(
                    'Existing priority, summary, streak and motivation controls',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    );
                    if (mounted) {
                      await CheckInService.apply(s);
                      setState(() {});
                    }
                  },
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Additional alerts are optional. They also require the master switch and iPhone notification permission.',
                  ),
                ),
                SwitchListTile(
                  title: const Text('Focus timer completion'),
                  value: s.prefs.getBool(s.key('v12_focusAlert')) ?? true,
                  onChanged: _busy ? null : (v) => change('v12_focusAlert', v),
                ),
                for (final type in CheckInService.types) ...[
                  SwitchListTile(
                    title: Text(
                      {
                        'planning': 'Daily planning',
                        'goals': 'Saturday goal check-in',
                        'review': 'Saturday weekly review',
                        'mood': 'Daily mood reminder',
                      }[type]!,
                    ),
                    value:
                        s.prefs.getBool(s.key(CheckInService.pref(type))) ??
                        false,
                    onChanged: _busy
                        ? null
                        : (v) => change(CheckInService.pref(type), v),
                  ),
                  ListTile(
                    title: const Text('Reminder time'),
                    subtitle: Text(
                      TimeOfDay(
                        hour:
                            s.prefs.getInt(
                              s.key('${CheckInService.pref(type)}Hour'),
                            ) ??
                            (type == 'planning' ? 9 : 18),
                        minute:
                            s.prefs.getInt(
                              s.key('${CheckInService.pref(type)}Minute'),
                            ) ??
                            0,
                      ).format(context),
                    ),
                    onTap: _busy ? null : () => time(type),
                  ),
                ],
                SwitchListTile(
                  title: const Text('Show mood check-in on Home'),
                  subtitle: const Text('Optional; no notification required'),
                  value: s.prefs.getBool(s.key('v12_moodPrompt')) ?? true,
                  onChanged: _busy ? null : (v) => change('v12_moodPrompt', v),
                ),
              ],
            ),
    );
  }
}
