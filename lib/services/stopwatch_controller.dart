import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import '../screens/notification_preferences.dart';
import '../screens/notification_service.dart';
import '../utils/stopwatch_session.dart';
import 'planning_store.dart';
import 'stopwatch_repository.dart';

class StopwatchController extends ChangeNotifier with WidgetsBindingObserver {
  StopwatchController._(this.store) {
    repo = StopwatchRepository(
      store,
      owner: () => owner,
      schedule: _schedule,
      cancel: _cancel,
    );
    WidgetsBinding.instance.addObserver(this);
  }
  static final _instances = <String, StopwatchController>{};
  static StopwatchController forStore(PlanningStore store) =>
      _instances.putIfAbsent(store.uid, () => StopwatchController._(store));
  final PlanningStore store;
  late final StopwatchRepository repo;
  Timer? _ticker;
  bool busy = false, loaded = false;
  String? error;
  bool get owner => FirebaseAuth.instance.currentUser?.uid == store.uid;
  StopwatchSession? get active => repo.active;
  String get preciseTime =>
      stopwatchTime(active?.elapsed(DateTime.now()) ?? 0, centiseconds: true);
  String get time => stopwatchTime(active?.elapsed(DateTime.now()) ?? 0);
  Future<void> load() async {
    try {
      await repo.load();
      loaded = true;
      if (owner) await repo.refreshReminders();
      error = null;
    } catch (_) {
      error = 'Could not load your stopwatch. Please retry.';
    }
    if (owner && _ticker?.isActive != true) {
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!owner) {
          _ticker?.cancel();
          return;
        }
        if (active?.running == true) notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> _cancel() async {
    if (!owner) return;
    for (var i = 0; i < 3; i++) {
      await NotificationService.cancelNotification(9020000 + i);
    }
  }

  Future<String?> _schedule(
    StopwatchSession s,
    DateTime now,
    bool requestPermission,
  ) async {
    if (!owner) return null;
    if (!await NotificationPreferences.notificationsEnabled()) {
      return 'Stopwatch reminders are off because the master notification switch is off.';
    }
    if (s.reminderMinutes == null) return null;
    if (requestPermission && !await NotificationService.requestPermissions()) {
      return 'Enable TrakOn notifications in iPhone Settings for stopwatch check-ins.';
    }
    final dates = stopwatchReminderTimes(s, now);
    for (var i = 0; i < dates.length; i++) {
      if (!owner) return null;
      await NotificationService.scheduleNotification(
        id: 9020000 + i,
        title: 'Still timing ${s.title}?',
        body:
            'Your stopwatch is running. Finished? Stop & Save your time in TrakOn.',
        scheduledTime: dates[i],
        payload: 'stopwatch:${s.id}',
      );
    }
    final pending = await NotificationService.getPendingNotifications();
    if (dates.isNotEmpty &&
        !pending.any((a) => a.id >= 9020000 && a.id <= 9020002)) {
      return 'Your stopwatch is running, but its check-ins could not be queued. Reopen Home and try again.';
    }
    return null;
  }

  Future<bool> run(Future<void> Function() job) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await job();
      return true;
    } catch (e) {
      error = e is StateError
          ? e.message.toString()
          : 'Could not save your stopwatch. Please retry.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> stopAndSave() => run(repo.stopAndSave);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && owner) {
      load();
    } else {
      _ticker?.cancel();
    }
  }
}
