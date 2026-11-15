import '../utils/planning_rules.dart' show TaskData;
import 'dart:convert';
import 'dart:math';
import '../utils/stopwatch_session.dart';
import 'planning_store.dart';

class StopwatchRepository {
  StopwatchRepository(
    this.store, {
    required this.schedule,
    required this.cancel,
    bool Function()? owner,
    DateTime Function()? now,
    String Function()? newId,
  }) : owner = owner ?? (() => true),
       now = now ?? DateTime.now,
       newId =
           newId ??
           (() =>
               '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}');
  final PlanningStore store;
  final Future<String?> Function(StopwatchSession, DateTime, bool) schedule;
  final Future<void> Function() cancel;
  final bool Function() owner;
  final DateTime Function() now;
  final String Function() newId;
  StopwatchSession? active;
  List<TaskData> history = [];
  String? reminderNotice;
  Future<void>? _loaded;
  Future<void> _tail = Future.value();
  String get _key => store.key('stopwatchActiveV17');
  Future<void> load() async {
    try {
      await (_loaded ??= _load());
    } catch (_) {
      _loaded = null;
      rethrow;
    }
  }

  Future<void> _load() async {
    final raw = store.prefs.getString(_key);
    active = raw == null
        ? null
        : StopwatchSession.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          );
    history = await store.listState('stopwatchSessionsV17');
  }

  void _checkOwner() {
    if (!owner()) throw StateError('Sign in to use your stopwatch.');
  }

  Future<T> _run<T>(Future<T> Function() job) {
    final next = _tail.catchError((Object _) {}).then((_) async {
      await load();
      _checkOwner();
      return job();
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _saveActive() async {
    final saved = active == null
        ? await store.prefs.remove(_key)
        : await store.prefs.setString(_key, jsonEncode(active!.toJson()));
    if (!saved) throw StateError('Could not save the stopwatch. Please retry.');
  }

  List<TaskData> forTask(String id, String date) => history
      .where(
        (r) =>
            r['taskId'] == id &&
            stopwatchTaskDate(r['taskDate'] as String?) ==
                stopwatchTaskDate(date),
      )
      .toList();
  int totalForTask(String id, String date) => forTask(
    id,
    date,
  ).fold(0, (n, r) => n + ((r['elapsedMs'] as num?)?.toInt() ?? 0));
  Future<void> _reminders({bool requestPermission = false}) async {
    _checkOwner();
    await cancel();
    _checkOwner();
    reminderNotice = active?.running == true
        ? await schedule(active!, now(), requestPermission)
        : null;
  }

  Future<void> refreshReminders() => _run(() => _reminders());
  Future<void> start({
    String title = 'Stopwatch',
    String? taskId,
    String? taskDate,
    String? taskTitle,
  }) => _run(() async {
    if (active != null) {
      throw StateError(
        'Save or reset the current stopwatch before starting another.',
      );
    }
    if (taskId != null && taskDate == null) {
      throw StateError('A task date is required.');
    }
    final at = now();
    final configuredReminder =
        store.prefs.getInt(store.key('stopwatchReminderV17')) ?? 60;
    active = StopwatchSession(
      id: newId(),
      title: title.trim().isEmpty ? 'Stopwatch' : title.trim(),
      createdAt: at.toUtc(),
      taskId: taskId,
      taskDate: stopwatchTaskDate(taskDate),
      taskTitle: taskTitle,
      reminderMinutes: configuredReminder == 0
          ? null
          : configuredReminder.clamp(1, 240),
    )..start(at);
    await _saveActive();
    await _reminders(requestPermission: true);
  });
  Future<void> resume() => _run(() async {
    active!.start(now());
    await _saveActive();
    await _reminders(requestPermission: true);
  });
  Future<void> pause() {
    final at = now();
    return _run(() async {
      active!.pause(at);
      await _saveActive();
      await _reminders();
    });
  }

  Future<void> lap() {
    final at = now();
    return _run(() async {
      active!.lap(at);
      await _saveActive();
    });
  }

  Future<void> rename(String title) => _run(() async {
    if (active == null || active!.finalizing) return;
    final trimmed = String.fromCharCodes(title.trim().runes.take(80));
    if (trimmed.isNotEmpty) active!.title = trimmed;
    await _saveActive();
    await _reminders();
  });
  Future<void> setReminder(int? minutes) => _run(() async {
    if (active == null || active!.finalizing) return;
    if (minutes != null && (minutes < 1 || minutes > 240)) {
      throw StateError('Choose a reminder interval from 1 to 240 minutes.');
    }
    active!.reminderMinutes = minutes;
    if (!await store.prefs.setInt(
      store.key('stopwatchReminderV17'),
      minutes ?? 0,
    )) {
      throw StateError('Could not save reminder preferences.');
    }
    await _saveActive();
    await _reminders(requestPermission: minutes != null);
  });
  Future<void> reset() => _run(() async {
    final s = active;
    if (s == null) return;
    if (s.finalizing) throw StateError('Retry Stop & Save before resetting.');
    active = StopwatchSession(
      id: newId(),
      title: s.title,
      createdAt: now().toUtc(),
      taskId: s.taskId,
      taskDate: s.taskDate,
      taskTitle: s.taskTitle,
      reminderMinutes: s.reminderMinutes,
    );
    await _saveActive();
    await _reminders();
  });
  Future<void> stopAndSave() {
    final stoppedAt = now();
    return _run(() async {
      final s = active;
      if (s == null) return;
      final at = stoppedAt;
      s.pause(at);
      s.endedAt ??= at.toUtc();
      // Durable frozen journal first; retrying after a failed clear cannot double-save.
      await _saveActive();
      _checkOwner();
      await cancel();
      _checkOwner();
      final record = {...s.toJson(), 'elapsedMs': s.accumulatedMs};
      final updated = history.where((r) => r['id'] != s.id).toList()
        ..add(record);
      await store.saveState('stopwatchSessionsV17', updated);
      history = updated;
      _checkOwner();
      // Keep the frozen journal in memory too until removal succeeds.
      if (!await store.prefs.remove(_key)) {
        throw StateError('Time is saved. Retry Stop & Save to finish.');
      }
      active = null;
      reminderNotice = null;
    });
  }
}
