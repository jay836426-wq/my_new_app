import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:TrakOn/services/planning_store.dart';

void main() {
  Future<PlanningStore> store(Map<String, Object> data) async {
    return PlanningStore(uid: 'u', prefs: MemoryPlanningPreferences(data));
  }

  test(
    'Rollover archives yesterday and resets recurring status and subtasks',
    () async {
      final template = {
        'id': 'r',
        'recurringId': 'series',
        'title': 'Read',
        'startDate': '2026-10-31',
        'date': '2026-10-31',
        'repeat': 'Daily',
        'completed': false,
        'subtasks': [
          {'id': 's', 'title': 'Page', 'completed': false},
        ],
      };
      final s = await store({
        'u_lastActiveDate': '2026-10-31',
        'u_tasks': jsonEncode([
          {
            ...template,
            'completed': true,
            'status': 'Complete',
            'subtasks': [
              {'id': 's', 'title': 'Page', 'completed': true},
            ],
          },
        ]),
        'u_recurringTasks': jsonEncode([template]),
      });
      await s.prepareToday(at: DateTime(2026, 11, 1));
      expect((await s.readDay('2026-10-31')).single['completed'], true);
      expect((await s.readDay('2026-11-1')).single['completed'], false);
      expect(
        ((await s.readDay('2026-11-1')).single['subtasks'] as List)
            .single['completed'],
        false,
      );
      expect(s.prefs.getString('u_taskCacheDate'), '2026-11-1');
    },
  );
  test('Rollover keeps future planned tasks and pending carry-over', () async {
    final s = await store({
      'u_lastActiveDate': '2026-10-31',
      'u_tasks': jsonEncode([
        {
          'id': 'old',
          'title': 'Call',
          'date': '2026-10-31',
          'completed': false,
        },
      ]),
      'u_tasks_2026-11-1': jsonEncode([
        {'id': 'planned', 'title': 'Appointment', 'date': '2026-11-1'},
      ]),
      'u_recurringTasks': '[]',
    });
    await s.prepareToday(at: DateTime(2026, 11, 1));
    await s.prepareToday(at: DateTime(2026, 11, 1));
    expect((await s.readDay('2026-11-1')).single['id'], 'planned');
    expect(s.carryOver.single['id'], 'old');
  });
  test(
    'Normal deletion survives a new store instance and restores original date',
    () async {
      final s = await store({
        'u_lastActiveDate': '2026-11-1',
        'u_tasks': jsonEncode([
          {
            'id': 'x',
            'title': 'Call',
            'date': '2026-11-1',
            'subtasks': [
              {'id': 'step', 'title': 'Dial', 'completed': true},
            ],
          },
        ]),
        'u_recurringTasks': '[]',
      });
      final entry = await s.deleteTask(
        '2026-11-1',
        (await s.readDay('2026-11-1')).single,
      );
      expect(await s.readDay('2026-11-1'), isEmpty);
      final reopened = PlanningStore(uid: 'u', prefs: s.prefs);
      expect(await reopened.listState('deletedTasks'), hasLength(1));
      await reopened.restoreDeleted(entry['id']);
      await reopened.restoreDeleted(entry['id']);
      expect(await reopened.readDay('2026-11-1'), hasLength(1));
      expect(
        ((await reopened.readDay('2026-11-1')).single['subtasks'] as List)
            .single['completed'],
        true,
      );
    },
  );
  test(
    'Deleting series stops future occurrences and keeps historical completions',
    () async {
      final template = {
        'id': 'r',
        'recurringId': 'series',
        'title': 'Read',
        'startDate': '2026-10-31',
        'date': '2026-10-31',
        'repeat': 'Daily',
      };
      final s = await store({
        'u_lastActiveDate': '2026-11-1',
        'u_tasks': jsonEncode([
          {...template, 'date': '2026-11-1'},
        ]),
        'u_tasks_2026-10-31': jsonEncode([
          {...template, 'completed': true},
        ]),
        'u_recurringTasks': jsonEncode([template]),
      });
      final entry = await s.deleteTask(
        '2026-11-1',
        (await s.readDay('2026-11-1')).single,
      );
      expect(await s.readDay('2026-11-2'), isEmpty);
      expect((await s.readDay('2026-10-31')).single['completed'], true);
      await s.restoreDeleted(entry['id']);
      expect(await s.readDay('2026-11-2'), hasLength(1));
    },
  );
  test('Deleting a future series leaves intervening dates scheduled', () async {
    final template = {
      'id': 'r',
      'recurringId': 'series',
      'title': 'Read',
      'startDate': '2026-10-31',
      'date': '2026-10-31',
      'repeat': 'Daily',
    };
    final prefs = MemoryPlanningPreferences({
      'u_lastActiveDate': '2026-11-1',
      'u_tasks': '[]',
      'u_recurringTasks': jsonEncode([template]),
    });
    final s = PlanningStore(uid: 'u', prefs: prefs);
    final entry = await s.deleteTask(
      '2026-11-5',
      (await s.readDay('2026-11-5')).single,
    );
    expect(await s.readDay('2026-11-4'), hasLength(1));
    expect(await s.readDay('2026-11-5'), isEmpty);
    await s.restoreDeleted(entry['id']);
    expect(await s.readDay('2026-11-6'), hasLength(1));
  });

  test(
    'Restoring one deletion does not undo another deletion of the same series',
    () async {
      final template = {
        'id': 'r',
        'recurringId': 'series',
        'title': 'Read',
        'startDate': '2026-10-31',
        'date': '2026-10-31',
        'repeat': 'Daily',
      };
      final s = await store({
        'u_lastActiveDate': '2026-11-1',
        'u_tasks': '[]',
        'u_recurringTasks': jsonEncode([template]),
      });
      final first = await s.deleteTask(
        '2026-11-5',
        (await s.readDay('2026-11-5')).single,
      );
      final second = await s.deleteTask(
        '2026-11-3',
        (await s.readDay('2026-11-3')).single,
      );
      await s.restoreDeleted(first['id']);
      expect(await s.readDay('2026-11-4'), isEmpty);
      await s.restoreDeleted(second['id']);
      expect(await s.readDay('2026-11-6'), hasLength(1));
    },
  );

  test('Task storage is isolated by account', () async {
    final s = await store({'u_recurringTasks': '[]'});
    await s.saveDay('2026-11-1', [
      {'id': 'secret', 'title': 'Private'},
    ]);
    final other = PlanningStore(uid: 'other', prefs: s.prefs);
    expect(await other.readDay('2026-11-1'), isEmpty);
  });
}

class MemoryPlanningPreferences implements PlanningPreferences {
  MemoryPlanningPreferences(Map<String, Object> values)
    : values = Map.of(values);
  final Map<String, Object> values;
  @override
  String? getString(String key) => values[key] as String?;
  @override
  int? getInt(String key) => values[key] as int?;
  @override
  bool? getBool(String key) => values[key] as bool?;
  @override
  Set<String> getKeys() => values.keys.toSet();
  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}
