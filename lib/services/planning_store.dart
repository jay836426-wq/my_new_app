import 'dart:convert';

import '../utils/planning_rules.dart';

abstract class PlanningPreferences {
  String? getString(String key);
  int? getInt(String key);
  bool? getBool(String key);
  Set<String> getKeys();
  Future<bool> setString(String key, String value);
  Future<bool> setInt(String key, int value);
  Future<bool> setBool(String key, bool value);
  Future<bool> remove(String key);
}

abstract class PlanningCloud {
  Future<TaskData?> readState();
  Future<void> saveState(TaskData fields);
  Future<List<TaskData>?> readDay(String date);
  Future<void> saveDay(String date, List<TaskData> tasks);
  Future<Map<String, List<TaskData>>> readDays();
}

/// All task dates have their own key. The old `tasks` key is only a compatibility
/// mirror, dated by taskCacheDate; it must never silently become the next day.
class PlanningStore {
  PlanningStore({
    required this.uid,
    required this.prefs,
    this.cloud,
    this.onSyncError,
  });
  final String uid;
  final PlanningPreferences prefs;
  final PlanningCloud? cloud;
  final void Function(Object)? onSyncError;
  String key(String value) => '${uid}_$value';
  List<TaskData> _decode(String? text) {
    if (text == null) return [];
    return (jsonDecode(text) as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  }

  Future<void> _set(String key, String value) async {
    if (!await prefs.setString(key, value)) {
      throw StateError('Could not save planner data.');
    }
  }

  Future<void> _stateCloud(TaskData fields) async {
    if (cloud == null) return;
    try {
      await cloud!.saveState(fields);
    } catch (e) {
      onSyncError?.call(e);
    }
  }

  Future<void> _dayCloud(String date, List<TaskData> tasks) async {
    if (cloud == null) return;
    try {
      await cloud!.saveDay(date, tasks);
    } catch (e) {
      onSyncError?.call(e);
    }
  }

  Future<TaskData?> _cloudState() async {
    if (cloud == null) return null;
    try {
      return await cloud!.readState();
    } catch (e) {
      onSyncError?.call(e);
      return null;
    }
  }

  Future<List<TaskData>> listState(String name) async {
    final raw = prefs.getString(key(name));
    if (raw != null) return _decode(raw);
    final state = await _cloudState();
    final value = state?[name];
    final result = value is List
        ? value.map((v) => Map<String, dynamic>.from(v as Map)).toList()
        : <TaskData>[];
    // Only establish an empty cache when an actual cloud response exists.
    if (state != null || cloud == null) {
      await _set(key(name), jsonEncode(result));
    }
    return result;
  }

  Future<void> saveState(String name, List<TaskData> value) async {
    await _set(key(name), jsonEncode(value));
    await _stateCloud({name: value});
  }

  Future<Map<String, dynamic>> _deletedSeries() async {
    final raw = prefs.getString(key('deletedSeries'));
    if (raw != null) return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final state = await _cloudState();
    final value = state?['deletedSeries'];
    final result = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    if (state != null || cloud == null) {
      await _set(key('deletedSeries'), jsonEncode(result));
    }
    return result;
  }

  Future<void> _saveDeletedSeries(Map<String, dynamic> value) async {
    await _set(key('deletedSeries'), jsonEncode(value));
    await _stateCloud({'deletedSeries': value});
  }

  Future<void> migrateLegacyCache() async {
    if (prefs.getBool(key('datedTaskStorageV12')) == true) return;
    final raw = prefs.getString(key('tasks'));
    final saved = _decode(raw);
    String? owner =
        prefs.getString(key('taskCacheDate')) ??
        prefs.getString(key('lastActiveDate'));
    if (owner == null || owner.isEmpty) {
      final dates = saved
          .map((t) => t['date']?.toString())
          .whereType<String>()
          .toSet();
      owner = dates.length == 1 ? dates.single : dayKey(DateTime.now());
    }
    if (raw != null) {
      if (prefs.getString(key('v12MigrationBackup')) == null) {
        await _set(
          key('v12MigrationBackup'),
          jsonEncode({
            'tasks': raw,
            'ownerDate': owner,
            'savedAt': DateTime.now().toUtc().toIso8601String(),
          }),
        );
      }
      // The active cache is authoritative for its own day; no cloud write to
      // today's date occurs until its owner has been established.
      await _set(key('tasks_$owner'), raw);
      await _set(key('taskCacheDate'), owner);
      await _dayCloud(owner, saved);
    }
    await prefs.setBool(key('datedTaskStorageV12'), true);
  }

  Future<List<TaskData>> _rawDay(String date) async {
    parseDay(date);
    await migrateLegacyCache();
    final local = prefs.getString(key('tasks_$date'));
    if (local != null) return _decode(local);
    if (cloud != null) {
      try {
        final tasks = await cloud!.readDay(date);
        if (tasks != null) {
          await _set(key('tasks_$date'), jsonEncode(tasks));
          return tasks;
        }
      } catch (e) {
        onSyncError?.call(e);
      }
    }
    return [];
  }

  Future<List<TaskData>> readDay(String date) async => materializeDay(
    saved: await _rawDay(date),
    templates: await listState('recurringTasks'),
    date: date,
    deletedSeries: await _deletedSeries(),
  );
  Future<void> saveDay(String date, List<TaskData> tasks) async {
    final snapshot = tasks.map(copyTask).toList();
    final encoded = jsonEncode(snapshot);
    await _set(key('tasks_$date'), encoded);
    if (date == dayKey(DateTime.now())) {
      await _set(key('tasks'), encoded);
      await _set(key('taskCacheDate'), date);
    }
    await _dayCloud(date, snapshot);
  }

  Future<void>? _rollover;
  String? previousDate;
  List<TaskData> carryOver = [];
  Future<void> prepareToday({DateTime? at}) async {
    final pending = _rollover;
    if (pending != null) return pending;
    final job = _prepareToday(at ?? DateTime.now());
    _rollover = job;
    try {
      await job;
    } finally {
      _rollover = null;
    }
  }

  Future<void> _prepareToday(DateTime now) async {
    await migrateLegacyCache();
    final today = dayKey(now);
    final old = prefs.getString(key('lastActiveDate'));
    previousDate = null;
    carryOver = [];
    if (old != null && old.isNotEmpty && old != today) {
      previousDate = old;
      carryOver = (await _rawDay(old))
          .where((t) => t['recurringId'] == null && !isTaskComplete(t))
          .map(copyTask)
          .toList();
    }
    if (carryOver.isNotEmpty) {
      await _set(
        key('pendingCarryOverV12'),
        jsonEncode({'date': previousDate, 'tasks': carryOver}),
      );
    } else {
      final pending = prefs.getString(key('pendingCarryOverV12'));
      if (pending != null) {
        final value = jsonDecode(pending) as Map;
        previousDate = value['date']?.toString();
        carryOver = (value['tasks'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
      }
    }
    final tasks = await readDay(today);
    // Date-owned tasks are durably cached before changing the active-day marker.
    final raw = jsonEncode(tasks);
    await _set(key('tasks_$today'), raw);
    await _set(key('tasks'), raw);
    await _set(key('taskCacheDate'), today);
    await _set(key('lastActiveDate'), today);
    await _stateCloud({'lastActiveDate': today});
  }

  Future<Map<String, List<TaskData>>> allSavedDays() async {
    await migrateLegacyCache();
    final days = <String, List<TaskData>>{};
    for (final k in prefs.getKeys()) {
      if (!k.startsWith(key('tasks_'))) continue;
      final date = k.substring(key('tasks_').length);
      try {
        parseDay(date);
        days[date] = _decode(prefs.getString(k));
      } catch (_) {
        continue;
      }
    }
    if (cloud != null) {
      try {
        final saved = await cloud!.readDays();
        for (final entry in saved.entries) {
          if (days.containsKey(entry.key)) continue;
          try {
            parseDay(entry.key);
          } catch (_) {
            continue;
          }
          days[entry.key] = entry.value;
        }
      } catch (e) {
        onSyncError?.call(e);
      }
    }
    final templates = await listState('recurringTasks');
    final deleted = await _deletedSeries();
    for (final date in days.keys.toList()) {
      days[date] = materializeDay(
        saved: days[date]!,
        templates: templates,
        date: date,
        deletedSeries: deleted,
      );
    }
    return days;
  }

  Future<TaskData> deleteTask(String date, TaskData task) async {
    final trash = await listState('deletedTasks');
    final templates = await listState('recurringTasks');
    final day = await readDay(date);
    final id = taskIdentity(task);
    final entry = <String, dynamic>{
      'id': '${DateTime.now().microsecondsSinceEpoch}-$id',
      'date': date,
      'deletedAt': DateTime.now().toIso8601String(),
      'index': day.indexWhere((t) => taskIdentity(t) == id),
      'task': copyTask(task),
      'templates': templates
          .where(
            (t) =>
                t['recurringId'] == task['recurringId'] &&
                task['recurringId'] != null,
          )
          .map(copyTask)
          .toList(),
    };
    // Use the first recovery snapshot as the original series settings when
    // the same series is deleted again from an earlier, still-active date.
    final seriesId = task['recurringId']?.toString();
    if (seriesId != null) {
      final earlier = trash.where(
        (e) => (e['task'] as Map?)?['recurringId']?.toString() == seriesId,
      );
      if (earlier.isNotEmpty) {
        entry['templates'] = copyTask(earlier.first)['templates'];
      }
    }
    // Keep the recovery snapshot before removing any task data.
    await saveState('deletedTasks', [...trash, entry]);
    if (task['recurringId'] != null) {
      final tombstones = await _deletedSeries();
      final log = await listState('seriesDeletionLog');
      log.add({'id': entry['id'], 'seriesId': seriesId, 'date': date});
      await saveState('seriesDeletionLog', log);
      final stops =
          log
              .where((e) => e['seriesId'] == seriesId)
              .map((e) => e['date'].toString())
              .toList()
            ..sort((a, b) => parseDay(a).compareTo(parseDay(b)));
      tombstones[seriesId!] = stops.first;
      await _saveDeletedSeries(tombstones);
      // Keep the series running before the selected deletion date.
      final stopDate = parseDay(tombstones[seriesId].toString());
      final until = dayKey(
        DateTime(stopDate.year, stopDate.month, stopDate.day - 1),
      );
      for (final template in templates) {
        if (template['recurringId'] == task['recurringId']) {
          final existing = template['repeatUntil'];
          if (existing is! String ||
              parseDay(existing).isAfter(parseDay(until))) {
            template['repeatUntil'] = until;
          }
        }
      }
      await saveState('recurringTasks', templates);
    }
    day.removeWhere((t) => taskIdentity(t) == id);
    await saveDay(date, day);
    return entry;
  }

  Future<void> restoreDeleted(String entryId) async {
    final trash = await listState('deletedTasks');
    final found = trash.where((t) => t['id'] == entryId);
    if (found.isEmpty) return;
    final entry = found.first;
    final date = entry['date'] as String;
    final task = Map<String, dynamic>.from(entry['task'] as Map);
    final templates = await listState('recurringTasks');
    for (final value in (entry['templates'] as List? ?? [])) {
      final template = Map<String, dynamic>.from(value as Map);
      final index = templates.indexWhere(
        (t) => t['recurringId'] == template['recurringId'],
      );
      if (index < 0) {
        templates.add(template);
      } else {
        templates[index] = template;
      }
    }
    if (task['recurringId'] != null) {
      final tombstones = await _deletedSeries();
      final seriesId = task['recurringId'].toString();
      final log = await listState('seriesDeletionLog');
      log.removeWhere((e) => e['id'] == entryId);
      await saveState('seriesDeletionLog', log);
      final stops =
          log
              .where((e) => e['seriesId'] == seriesId)
              .map((e) => e['date'].toString())
              .toList()
            ..sort((a, b) => parseDay(a).compareTo(parseDay(b)));
      if (stops.isEmpty) {
        tombstones.remove(seriesId);
      } else {
        tombstones[seriesId] = stops.first;
        final stop = parseDay(stops.first);
        final until = dayKey(DateTime(stop.year, stop.month, stop.day - 1));
        for (final t in templates) {
          if (t['recurringId'].toString() == seriesId) {
            final existing = t['repeatUntil'];
            if (existing is! String ||
                parseDay(existing).isAfter(parseDay(until))) {
              t['repeatUntil'] = until;
            }
          }
        }
      }
      await _saveDeletedSeries(tombstones);
      await saveState('recurringTasks', templates);
    }
    final day = await _rawDay(date);
    if (!day.any((t) => taskIdentity(t) == taskIdentity(task))) {
      final index = ((entry['index'] as num?)?.toInt() ?? day.length).clamp(
        0,
        day.length,
      );
      day.insert(index, task);
    }
    await saveDay(date, day);
    trash.removeWhere((t) => t['id'] == entryId);
    await saveState('deletedTasks', trash);
  }

  Future<void> permanentlyDelete(String entryId) async {
    final trash = await listState('deletedTasks');
    trash.removeWhere((t) => t['id'] == entryId);
    await saveState('deletedTasks', trash);
  }
}
