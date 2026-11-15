import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:TrakOn/services/planning_store.dart';
import 'package:TrakOn/services/stopwatch_repository.dart';
import 'package:TrakOn/utils/stopwatch_session.dart';

class StopwatchPrefs implements PlanningPreferences {
  final values = <String, Object>{};
  bool failClear = false, failHistory = false;
  @override
  String? getString(String k) => values[k] as String?;
  @override
  int? getInt(String k) => values[k] as int?;
  @override
  bool? getBool(String k) => values[k] as bool?;
  @override
  Set<String> getKeys() => values.keys.toSet();
  @override
  Future<bool> setString(String k, String v) async {
    if (failHistory && k.endsWith('stopwatchSessionsV17')) return false;
    values[k] = v;
    return true;
  }

  @override
  Future<bool> setInt(String k, int v) async {
    values[k] = v;
    return true;
  }

  @override
  Future<bool> setBool(String k, bool v) async {
    values[k] = v;
    return true;
  }

  @override
  Future<bool> remove(String k) async {
    if (failClear && k.endsWith('stopwatchActiveV17')) return false;
    values.remove(k);
    return true;
  }
}

void main() {
  late DateTime now;
  late StopwatchPrefs prefs;
  late PlanningStore store;
  late StopwatchRepository repo;
  late List<StopwatchSession> scheduled;
  late int cancels, ids;
  var owner = true;
  StopwatchRepository make([PlanningStore? s]) => StopwatchRepository(
    s ?? store,
    owner: () => owner,
    now: () => now,
    newId: () => 'session-${++ids}',
    cancel: () async {
      cancels++;
    },
    schedule: (value, _, _) async {
      scheduled.add(StopwatchSession.fromJson(value.toJson()));
      return null;
    },
  );
  setUp(() async {
    now = DateTime.utc(2026, 11, 15, 9);
    owner = true;
    ids = 0;
    cancels = 0;
    scheduled = [];
    prefs = StopwatchPrefs();
    store = PlanningStore(uid: 'u', prefs: prefs);
    repo = make();
    await repo.load();
  });
  Future<void> gym() => repo.start(
    title: 'Gym',
    taskId: 'gym',
    taskDate: '2026-11-15',
    taskTitle: 'Gym',
  );
  test(
    'task times are saved by ID and date without rewriting task status',
    () async {
      final taskDay = jsonEncode([
        {'id': 'gym', 'title': 'Gym', 'status': 'In Progress'},
      ]);
      prefs.values['u_tasks_2026-11-15'] = taskDay;
      await gym();
      now = now.add(const Duration(minutes: 30));
      await repo.stopAndSave();
      expect(repo.active, isNull);
      expect(repo.forTask('gym', '2026-11-15').length, 1);
      expect(repo.totalForTask('gym', '2026-11-15'), 1800000);
      expect(repo.forTask('gym', '2026-11-16'), isEmpty);
      expect(prefs.values['u_tasks_2026-11-15'], taskDay);
    },
  );
  test(
    'restarting the app preserves the active task and elapsed time',
    () async {
      await gym();
      now = now.add(const Duration(minutes: 10));
      final restarted = make();
      await restarted.load();
      expect(restarted.active!.matchesTask('gym', '2026-11-15'), true);
      expect(restarted.active!.elapsed(now), 600000);
    },
  );
  test(
    'saving after a failed journal clear is idempotent across restart',
    () async {
      await gym();
      now = now.add(const Duration(minutes: 2));
      prefs.failClear = true;
      await expectLater(repo.stopAndSave(), throwsStateError);
      expect(repo.active!.finalizing, true);
      expect(repo.history.length, 1);
      now = now.add(const Duration(hours: 1));
      repo = make();
      await repo.load();
      expect(repo.active!.elapsed(now), 120000);
      prefs.failClear = false;
      await repo.stopAndSave();
      expect(repo.history.length, 1);
      expect(repo.totalForTask('gym', '2026-11-15'), 120000);
      expect(repo.active, isNull);
    },
  );
  test('history failure retains a frozen session for retry', () async {
    await gym();
    now = now.add(const Duration(minutes: 3));
    prefs.failHistory = true;
    final beforeCancel = cancels;
    await expectLater(repo.stopAndSave(), throwsStateError);
    expect(repo.active!.finalizing, true);
    expect(cancels, greaterThan(beforeCancel));
    expect(repo.history, isEmpty);
    now = now.add(const Duration(minutes: 30));
    prefs.failHistory = false;
    await repo.stopAndSave();
    expect(repo.totalForTask('gym', '2026-11-15'), 180000);
    expect(repo.history.length, 1);
  });
  test('another task cannot silently replace the current stopwatch', () async {
    await gym();
    await expectLater(
      repo.start(title: 'Walk', taskId: 'walk', taskDate: '2026-11-15'),
      throwsStateError,
    );
    expect(repo.active!.taskId, 'gym');
  });
  test(
    'pause and Stop & Save cancel check-ins without ending a Focus timer',
    () async {
      await gym();
      expect(scheduled.single.title, 'Gym');
      final before = cancels;
      now = now.add(const Duration(minutes: 5));
      await repo.pause();
      expect(cancels, greaterThan(before));
      expect(scheduled.length, 1);
      await repo.resume();
      expect(scheduled.length, 2);
      final beforeSave = cancels;
      await repo.stopAndSave();
      expect(cancels, greaterThan(beforeSave));
      // The callback owns only stopwatch IDs; the repository never invokes Focus APIs.
      expect(repo.active, isNull);
    },
  );
  test('laps and renaming preserve task link and total duration', () async {
    await gym();
    now = now.add(const Duration(seconds: 30));
    await repo.lap();
    await repo.rename('Leg day');
    now = now.add(const Duration(seconds: 30));
    await repo.stopAndSave();
    final record = repo.history.single;
    expect(record['taskId'], 'gym');
    expect(record['title'], 'Leg day');
    expect(record['elapsedMs'], 60000);
    expect(record['laps'], [30000]);
  });
  test(
    'reset clears only unsaved time and laps and cancels check-ins',
    () async {
      await gym();
      now = now.add(const Duration(minutes: 1));
      await repo.lap();
      final before = cancels;
      await repo.reset();
      expect(repo.active!.running, false);
      expect(repo.active!.elapsed(now), 0);
      expect(repo.active!.laps, isEmpty);
      expect(repo.active!.taskId, 'gym');
      expect(repo.history, isEmpty);
      expect(cancels, greaterThan(before));
    },
  );
  test('off reminder preference is remembered for the next session', () async {
    await gym();
    await repo.setReminder(null);
    await repo.stopAndSave();
    await repo.start(title: 'Walk');
    expect(repo.active!.reminderMinutes, isNull);
  });
  test('saved sessions stay separate between accounts', () async {
    await gym();
    now = now.add(const Duration(minutes: 1));
    await repo.stopAndSave();
    final other = make(PlanningStore(uid: 'other', prefs: prefs));
    await other.load();
    expect(other.history, isEmpty);
    expect(other.active, isNull);
  });
  test(
    'sign-out prevents old stopwatch actions and reminder refresh',
    () async {
      await gym();
      owner = false;
      final before = cancels;
      await expectLater(repo.stopAndSave(), throwsStateError);
      await expectLater(repo.refreshReminders(), throwsStateError);
      expect(cancels, before);
      expect(repo.history, isEmpty);
    },
  );
  test('unlinked stopwatch sessions do not inflate task totals', () async {
    await repo.start(title: 'Reading');
    now = now.add(const Duration(minutes: 15));
    await repo.stopAndSave();
    expect(repo.history.single['taskId'], isNull);
    expect(repo.totalForTask('gym', '2026-11-15'), 0);
  });
  test(
    'Stop & Save captures the tap time even when earlier work is queued',
    () async {
      var hold = false;
      final gate = Completer<void>();
      repo = StopwatchRepository(
        store,
        now: () => now,
        newId: () => 'queued-session',
        cancel: () async {
          if (hold) await gate.future;
        },
        schedule: (s, n, p) async => null,
      );
      await repo.load();
      await gym();
      hold = true;
      final refresh = repo.refreshReminders();
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(minutes: 1));
      final saving = repo.stopAndSave();
      now = now.add(const Duration(minutes: 10));
      hold = false;
      gate.complete();
      await refresh;
      await saving;
      expect(repo.history.single['elapsedMs'], 60000);
    },
  );
}
