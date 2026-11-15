import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../utils/focus_clock.dart';
import '../screens/notification_service.dart';
import '../screens/notification_preferences.dart';
import 'focus_alarm_bridge.dart';
import 'planning_store.dart';

/// One controller per signed-in account, shared by Home and the full timer.
class FocusTimerController extends ChangeNotifier with WidgetsBindingObserver {
  FocusTimerController._(
    this.store, {
    this.ownerCheck,
    this.scheduleOverride,
    this.cancelOverride,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
  }
  factory FocusTimerController.testing(
    PlanningStore store, {
    required bool Function() ownerCheck,
    required Future<void> Function(FocusClock, bool) schedule,
    required Future<void> Function() cancel,
    required DateTime Function() now,
  }) => FocusTimerController._(
    store,
    ownerCheck: ownerCheck,
    scheduleOverride: schedule,
    cancelOverride: cancel,
    now: now,
  );
  final bool Function()? ownerCheck;
  final Future<void> Function(FocusClock, bool)? scheduleOverride;
  final Future<void> Function()? cancelOverride;
  final DateTime Function() now;
  Future<void> cancelAlert() =>
      cancelOverride?.call() ?? NotificationService.cancelNotification(9000007);
  static final _instances = <String, FocusTimerController>{};
  static FocusTimerController forStore(PlanningStore store) =>
      _instances.putIfAbsent(store.uid, () => FocusTimerController._(store));
  final PlanningStore store;
  FocusClock? clock;
  bool busy = false;
  String? error;
  String? alertMessage;
  Future<void>? _loading;
  Future<void> _tail = Future.value();
  Timer? _ticker;
  bool _savingExpiry = false;
  bool _sessionStarted = false;
  bool get owner =>
      ownerCheck?.call() ??
      (FirebaseAuth.instance.currentUser?.uid == store.uid);
  bool get complete =>
      clock != null && !clock!.running && clock!.pausedSeconds == 0;
  bool get paused =>
      clock != null &&
      !clock!.running &&
      clock!.pausedSeconds > 0 &&
      (_sessionStarted || clock!.pausedSeconds < clock!.durationSeconds);
  int get remaining => clock?.remaining(now()) ?? 0;
  String get timeLabel =>
      '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';
  String get sessionName => clock?.title.isNotEmpty == true
      ? clock!.title
      : '${clock?.mode ?? 'Focus'} session';
  int minutesFor(String mode) =>
      (store.prefs.getInt(store.key('focusMinutesV17_$mode')) ??
              (mode == 'Break' ? 5 : 25))
          .clamp(1, 180);
  String nameFor(String mode) =>
      store.prefs.getString(store.key('focusNameV17_$mode')) ??
      (mode == 'Break' ? 'Take a breather' : 'One thing at a time');

  Future<void> load() async {
    _loading ??= _load();
    try {
      await _loading;
    } catch (_) {
      _loading = null;
      rethrow;
    }
    if (owner && _ticker?.isActive != true) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  Future<void> _load() async {
    try {
      final raw = store.prefs.getString(store.key('focusTimerV12'));
      clock = raw == null
          ? FocusClock(title: nameFor('Focus'))
          : FocusClock.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
      _sessionStarted =
          store.prefs.getBool(store.key('focusSessionStartedV17')) ??
          (clock!.running || clock!.pausedSeconds < clock!.durationSeconds);
      if (store.prefs.getInt(store.key('focusMinutesV17_${clock!.mode}')) ==
          null) {
        await store.prefs.setInt(
          store.key('focusMinutesV17_${clock!.mode}'),
          clock!.durationSeconds ~/ 60,
        );
      }
      if (clock!.finishIfExpired(now())) await _save();
      error = null;
    } catch (_) {
      error = 'Could not load your timer. Please retry.';
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  void _tick() {
    if (!owner) {
      _ticker?.cancel();
      return;
    }
    if (clock == null || busy || _savingExpiry) return;
    final finished = clock!.finishIfExpired(now());
    if (finished) {
      _savingExpiry = true;
      _save()
          .catchError((Object _) {
            error = 'Could not save the completed session.';
          })
          .whenComplete(() {
            _savingExpiry = false;
            notifyListeners();
          });
    }
    if (clock!.running || finished) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && owner) _tick();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (identical(_instances[store.uid], this)) _instances.remove(store.uid);
    super.dispose();
  }

  Future<void> _save() async {
    if (!await store.prefs.setBool(
      store.key('focusSessionStartedV17'),
      _sessionStarted,
    )) {
      throw StateError('Timer state could not be saved');
    }
    if (!await store.prefs.setString(
      store.key('focusTimerV12'),
      jsonEncode(clock!.toJson()),
    )) {
      throw StateError('Timer could not be saved');
    }
  }

  Future<void> _change(Future<void> Function() change) {
    final next = _tail.catchError((Object _) {}).then((_) async {
      await load();
      if (!owner || clock == null) return;
      busy = true;
      error = null;
      notifyListeners();
      try {
        clock!.finishIfExpired(now());
        await change();
        await _save();
      } catch (_) {
        error = 'Could not update your timer. Please try again.';
      } finally {
        busy = false;
        notifyListeners();
      }
    });
    _tail = next;
    return next;
  }

  Future<void> _schedule({bool requestPermission = false}) async {
    await cancelAlert();
    alertMessage = null;
    if (!clock!.running) return;
    if (scheduleOverride != null) {
      await scheduleOverride!(
        FocusClock.fromJson(clock!.toJson()),
        requestPermission,
      );
      return;
    }
    if (!await NotificationPreferences.notificationsEnabled() ||
        !(store.prefs.getBool(store.key('v12_focusAlert')) ?? true)) {
      alertMessage =
          'Timer started without an alert. Enable Focus timer completion in Notifications & reminders.';
      return;
    }
    var notificationsAllowed = true;
    if (requestPermission) {
      await FocusAlarmBridge.requestAuthorization();
      notificationsAllowed = await NotificationService.requestPermissions();
    }
    if (!owner) return;
    await NotificationService.scheduleNotification(
      id: 9000007,
      title: clock!.mode == 'Break'
          ? 'Break complete'
          : 'Focus session complete',
      body: sessionName,
      scheduledTime: clock!.deadline!,
      payload: 'focus',
    );
    if (FocusAlarmBridge.backend != 'alarm') {
      if (!notificationsAllowed) {
        alertMessage =
            'Timer started, but background sound needs notification permission in iPhone Settings.';
        return;
      }
      final queued = await NotificationService.getPendingNotifications();
      if (!queued.any((a) => a.id == 9000007)) {
        alertMessage =
            'Timer started, but its background alert could not be scheduled. Open Home to refresh reminders and try again.';
        return;
      }
    }
    alertMessage = FocusAlarmBridge.backend == 'alarm'
        ? 'A system alarm will ring when this session ends. Tap Stop to dismiss it.'
        : FocusAlarmBridge.warning ??
              'A notification will sound when this session ends. Silent mode and Focus settings apply.';
  }

  Future<void> start() => _change(() async {
    clock!.start(now());
    _sessionStarted = true;
    // Persist before requesting permissions; process restarts retain the deadline.
    await _save();
    await _schedule(requestPermission: true);
  });
  Future<void> pause() => _change(() async {
    clock!.pause(now());
    await cancelAlert();
    alertMessage = null;
  });
  Future<void> reset() => _change(() async {
    await cancelAlert();
    clock!.reset();
    _sessionStarted = false;
    alertMessage = null;
  });
  Future<void> dismiss() => _change(() async {
    await cancelAlert();
    clock!.reset();
    _sessionStarted = false;
    alertMessage = null;
  });
  Future<void> configure(
    String mode, {
    int? minutes,
    bool startImmediately = false,
  }) => _change(() async {
    await cancelAlert();
    clock!.mode = mode == 'Break' ? 'Break' : 'Focus';
    clock!.durationSeconds =
        (minutes ?? minutesFor(clock!.mode)).clamp(1, 180) * 60;
    clock!.title = nameFor(clock!.mode);
    clock!.reset();
    _sessionStarted = false;
    alertMessage = null;
    await store.prefs.setInt(
      store.key('focusMinutesV17_${clock!.mode}'),
      clock!.durationSeconds ~/ 60,
    );
    if (startImmediately) {
      clock!.start(now());
      _sessionStarted = true;
      await _save();
      await _schedule(requestPermission: true);
    }
  });
  Future<void> rename(String name) => _change(() async {
    final trimmed = String.fromCharCodes(name.trim().runes.take(80));
    clock!.title = trimmed.isEmpty ? nameFor(clock!.mode) : trimmed;
    await store.prefs.setString(
      store.key('focusNameV17_${clock!.mode}'),
      clock!.title,
    );
    await _save();
    if (clock!.running) await _schedule();
  });
  Future<void> nameFromTask(String title) async {
    await load();
    if (clock == null || clock!.running || paused) return;
    await configure('Focus');
    await rename(title);
  }
}
