import '../services/account_planning_store.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/planning_store.dart';
import '../utils/focus_clock.dart';
import 'notification_service.dart';
import 'notification_preferences.dart';

class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key, this.taskTitle});
  final String? taskTitle;
  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen>
    with WidgetsBindingObserver {
  static const _notificationId = 9000007;
  FocusClock? _clock;
  PlanningStore? _store;
  Timer? _timer;
  bool _busy = false;
  String? _error;
  String? _alertStatus;
  String? _completion;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    try {
      final store = await AccountPlanningStore.current();
      final raw = store.prefs.getString(store.key('focusTimerV12'));
      final clock = raw == null
          ? FocusClock()
          : FocusClock.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
      if (widget.taskTitle != null && !clock.running) {
        clock.title = widget.taskTitle!;
      }
      _store = store;
      _clock = clock;
      if (clock.finishIfExpired(DateTime.now())) {
        _completion = '${clock.mode} complete';
      }
      await persist();
      if (!mounted) return;
      setState(() {});
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the focus timer.');
    }
  }

  Future<void> persist() async {
    final store = _store;
    if (store == null || _clock == null) return;
    final saved = await store.prefs.setString(
      store.key('focusTimerV12'),
      jsonEncode(_clock!.toJson()),
    );
    if (!saved) throw StateError('Could not save timer');
  }

  void tick() {
    if (!mounted || _clock == null || _busy) return;
    if (_clock!.finishIfExpired(DateTime.now())) {
      _completion = '${_clock!.mode} complete';
      if (_foreground) {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      }
      persist().catchError((Object e) {
        if (mounted) setState(() => _error = 'Could not save this session.');
      });
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> action(String action, {int? minutes, String? mode}) async {
    if (_busy || _clock == null) return;
    setState(() => _busy = true);
    try {
      final clock = _clock!;
      clock.finishIfExpired(DateTime.now());
      if (action == 'pause') clock.pause(DateTime.now());
      if (action == 'reset') clock.reset();
      if (action == 'configure') {
        clock.durationSeconds = minutes! * 60;
        clock.mode = mode ?? clock.mode;
        clock.reset();
      }
      if (action == 'start') clock.start(DateTime.now());
      await persist();
      _completion = null;
      try {
        await NotificationService.init();
        await NotificationService.cancelNotification(_notificationId);
        if (!clock.running) {
          _alertStatus = 'Timer alert cleared.';
        } else if (!await NotificationPreferences.notificationsEnabled() ||
            !(_store!.prefs.getBool(_store!.key('v12_focusAlert')) ?? true)) {
          _alertStatus =
              'Timer is running without an alert. Enable the master notification switch and Focus timer completion in Reminders & check-ins.';
        } else if (!await NotificationService.requestPermissions()) {
          _alertStatus =
              'Timer is running without an alert. Notification permission was not granted. Check iPhone Settings.';
        } else {
          await _queueAlert(
            _notificationId,
            clock.deadline!,
            clock.mode == 'Focus' ? 'Focus session complete' : 'Break complete',
            clock.title.isEmpty ? 'Time to take your next step.' : clock.title,
          );
        }
      } catch (e) {
        _alertStatus = 'Timer saved, but its alert could not be confirmed: $e';
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not save timer changes. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _queueAlert(
    int id,
    DateTime deadline,
    String title,
    String body,
  ) async {
    final plugin = NotificationService.notificationsPlugin;
    // The shared scheduler reserves timer space without deleting check-ins.
    await NotificationService.scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledTime: deadline,
      payload: 'focus',
    );
    final pending = await plugin.pendingNotificationRequests();
    final queued = pending.any((n) => n.id == id);
    if (!mounted) return;
    _alertStatus = queued
        ? 'iOS queued the alert for ${TimeOfDay.fromDateTime(deadline.toLocal()).format(context)}. ${pending.length} alerts pending. Queued does not guarantee delivery.'
        : 'The timer is running, but iOS did not report its alert in the pending queue. ${pending.length} other alerts pending.';
  }

  Future<void> _testAlert() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await NotificationService.init();
      if (!await NotificationPreferences.notificationsEnabled() ||
          !(_store!.prefs.getBool(_store!.key('v12_focusAlert')) ?? true)) {
        _alertStatus =
            'Enable the master switch and Focus timer completion before testing.';
      } else if (!await NotificationService.requestPermissions()) {
        _alertStatus = 'Notification permission was not granted.';
      } else {
        await _queueAlert(
          9000019,
          DateTime.now().add(const Duration(seconds: 10)),
          'TrakOn timer test',
          'If you can see this, a scheduled alert reached your iPhone.',
        );
      }
    } catch (e) {
      _alertStatus = 'Test could not be scheduled: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> customDuration() async {
    final controller = TextEditingController(
      text: ((_clock!.durationSeconds) ~/ 60).toString(),
    );
    final minutes = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Session length'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes (1–180)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              if (n != null && n >= 1 && n <= 180) Navigator.pop(c, n);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (minutes != null) await action('configure', minutes: minutes);
  }

  @override
  Widget build(BuildContext context) {
    final clock = _clock;
    final seconds = clock?.remaining(DateTime.now()) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Focus timer')),
      body: clock == null
          ? Center(
              child: _error != null
                  ? Text(_error!)
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Focus', label: Text('Focus')),
                    ButtonSegment(value: 'Break', label: Text('Break')),
                  ],
                  selected: {clock.mode},
                  onSelectionChanged: clock.running || _busy
                      ? null
                      : (v) => action(
                          'configure',
                          minutes: v.first == 'Focus' ? 25 : 5,
                          mode: v.first,
                        ),
                ),
                const SizedBox(height: 28),
                Text(
                  clock.title.isEmpty ? 'One thing at a time' : clock.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 230,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: seconds / clock.durationSeconds,
                          strokeWidth: 10,
                          color: Colors.greenAccent,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      Text(
                        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    for (final m in [15, 25, 45, 60])
                      ChoiceChip(
                        label: Text('$m min'),
                        selected: clock.durationSeconds == m * 60,
                        onSelected: clock.running || _busy
                            ? null
                            : (_) => action('configure', minutes: m),
                      ),
                  ],
                ),
                TextButton(
                  onPressed: clock.running || _busy ? null : customDuration,
                  child: const Text('Custom length'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => action(clock.running ? 'pause' : 'start'),
                  icon: Icon(clock.running ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    clock.running
                        ? 'Pause'
                        : seconds == 0
                        ? 'Start again'
                        : 'Start / Resume',
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => action('reset'),
                  child: const Text('Reset timer'),
                ),
                Text(
                  '${clock.sessions} focus sessions completed on this device',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'The timer keeps time while the app is in the background. A completion alert requires notification permission.',
                  textAlign: TextAlign.center,
                ),
                if (_completion != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                      ),
                      title: Text(_completion!),
                      subtitle: const Text('Your session has ended.'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _completion = null),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _testAlert,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Test alert in 10 seconds'),
                ),
                if (_alertStatus != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_alertStatus!),
                  ),
                if (_error != null) Text(_error!),
              ],
            ),
    );
  }
}
