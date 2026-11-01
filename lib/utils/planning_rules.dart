import 'dart:convert';
import 'dart:math' as math;

typedef TaskData = Map<String, dynamic>;
String dayKey(DateTime date) => '${date.year}-${date.month}-${date.day}';
DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime parseDay(String text) {
  final p = text.split('-').map(int.parse).toList();
  if (p.length != 3) throw const FormatException('Invalid task date');
  final d = DateTime(p[0], p[1], p[2]);
  if (d.year != p[0] || d.month != p[1] || d.day != p[2]) {
    throw const FormatException('Invalid task date');
  }
  return d;
}

TaskData copyTask(TaskData task) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(task)) as Map);
int civilDays(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
bool taskRunsOnDate(TaskData task, DateTime date) {
  final startText = task['startDate'] ?? task['date'];
  if (startText is! String) return false;
  DateTime start;
  try {
    start = parseDay(startText);
  } catch (_) {
    return false;
  }
  date = dayOnly(date);
  final delta = civilDays(start, date);
  if (delta < 0) return false;
  final endText = task['repeatUntil'];
  if (endText is String) {
    try {
      if (date.isAfter(parseDay(endText))) return false;
    } catch (_) {
      return false;
    }
  }
  final interval = math.max(1, (task['repeatInterval'] as num?)?.toInt() ?? 1);
  switch (task['repeat']) {
    case 'Daily':
      return true;
    case 'Weekdays':
      return date.weekday <= 5;
    case 'Weekly':
      return delta % 7 == 0;
    case 'Specific Days':
      return (task['repeatDays'] as List? ?? []).contains(date.weekday);
    case 'Every N Days':
      return delta % interval == 0;
    case 'Every N Weeks':
      return delta % (7 * interval) == 0;
    case 'Monthly':
      return date.day ==
          math.min(start.day, DateTime(date.year, date.month + 1, 0).day);
    case 'Yearly':
      return date.month == start.month &&
          date.day ==
              math.min(start.day, DateTime(date.year, date.month + 1, 0).day);
    default:
      return false;
  }
}

String taskIdentity(TaskData task) =>
    (task['id'] ??
            task['recurringId'] ??
            task['notificationId'] ??
            '${task['title']}|${task['startDate'] ?? task['date']}')
        .toString();
bool isTaskComplete(TaskData task) =>
    task['completed'] == true || task['status'] == 'Complete';
List<TaskData> taskSubtasks(TaskData task) => (task['subtasks'] as List? ?? [])
    .whereType<Map>()
    .map((v) => Map<String, dynamic>.from(v))
    .toList();
List<TaskData> materializeDay({
  required List<TaskData> saved,
  required List<TaskData> templates,
  required String date,
  Map<String, dynamic> deletedSeries = const {},
  DateTime? asOf,
}) {
  final result = <TaskData>[];
  final day = parseDay(date);
  bool deleted(TaskData task) {
    final from = deletedSeries[task['recurringId']?.toString()];
    return from is String && !day.isBefore(parseDay(from));
  }

  final seen = <String>{};
  for (final task in saved) {
    if (deleted(task)) continue;
    if (task['recurringId'] == null) {
      final copy = copyTask(task)..['date'] = date;
      if (seen.add(taskIdentity(copy))) result.add(copy);
    } else if (day.isBefore(dayOnly(asOf ?? DateTime.now())) &&
        (task['date'] == null || task['date'] == date)) {
      // Later schedule/name/checklist edits must not rewrite saved history.
      final copy = copyTask(task)..['date'] = date;
      if (seen.add(taskIdentity(copy))) result.add(copy);
    } else if (!templates.any((t) => t['recurringId'] == task['recurringId'])) {
      // Removing a series must not erase its saved historical occurrences.
      if (task['date'] == date || task['date'] == null) {
        result.add(copyTask(task)..['date'] = date);
      }
    }
  }
  for (final template in templates) {
    if (deleted(template) || !taskRunsOnDate(template, day)) continue;
    TaskData? existing;
    for (final task in saved) {
      if (task['recurringId'] == template['recurringId'] &&
          (task['date'] == null || task['date'] == date)) {
        existing = task;
        break;
      }
    }
    final occurrence = copyTask(template)..['date'] = date;
    occurrence['completed'] = existing == null
        ? false
        : isTaskComplete(existing);
    occurrence['status'] = existing == null
        ? 'Not Started'
        : isTaskComplete(existing)
        ? 'Complete'
        : existing['status'] ?? 'Not Started';
    occurrence.remove('previousStatus');
    if (existing?['previousStatus'] is String) {
      occurrence['previousStatus'] = existing!['previousStatus'];
    }
    final existingSubs = existing == null
        ? <TaskData>[]
        : taskSubtasks(existing);
    occurrence['subtasks'] = taskSubtasks(template).map((sub) {
      final match = existingSubs.where((s) => s['id'] == sub['id']);
      return {
        ...sub,
        'completed': match.isNotEmpty && match.first['completed'] == true,
      };
    }).toList();
    if (seen.add(taskIdentity(occurrence))) result.add(occurrence);
  }
  return result;
}

int? timeMinutes(Object? text) {
  if (text is! String) return null;
  final m = RegExp(
    r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$',
    caseSensitive: false,
  ).firstMatch(text.trim());
  if (m == null) return null;
  var h = int.parse(m[1]!);
  final minute = int.parse(m[2]!);
  if (minute > 59) return null;
  if (m[3] != null) {
    if (h < 1 || h > 12) return null;
    h = h % 12 + (m[3]!.toUpperCase() == 'PM' ? 12 : 0);
  }
  if (h > 23) return null;
  return h * 60 + minute;
}

String minutesLabel(int minutes) {
  final h = minutes ~/ 60;
  return '${h % 12 == 0 ? 12 : h % 12}:${(minutes % 60).toString().padLeft(2, '0')} ${h >= 12 ? 'PM' : 'AM'}';
}

int? taskDuration(TaskData task) {
  final start = timeMinutes(task['startTime']);
  final end = timeMinutes(task['endTime']);
  if (start != null && end != null && end > start) return end - start;
  return (task['durationMinutes'] as num?)?.toInt();
}

String? validatePlanningTask(TaskData task) {
  if ((task['title']?.toString().trim() ?? '').isEmpty) {
    return 'Enter a task name.';
  }
  if (task['repeat'] == 'Specific Days' &&
      (task['repeatDays'] as List? ?? []).isEmpty) {
    return 'Choose at least one repeat day.';
  }
  final n = (task['repeatInterval'] as num?)?.toInt() ?? 1;
  if (n < 1 || n > 365) return 'Repeat interval must be between 1 and 365.';
  if (task['repeat'] == 'Every N Weeks' && n > 52) {
    return 'Choose a repeat interval from 1 to 52 weeks.';
  }
  final dur = (task['durationMinutes'] as num?)?.toInt();
  if (dur != null && (dur < 1 || dur > 1439)) {
    return 'Duration must be between 1 and 1439 minutes.';
  }
  final start = timeMinutes(task['startTime']);
  final end = timeMinutes(task['endTime']);
  if (start != null && end != null && end <= start) {
    return 'End time must be after start time.';
  }
  if (start != null && dur != null && start + dur >= 1440) {
    return 'This time block must end before midnight.';
  }
  if (task['repeat'] != 'Never' && task['repeatUntil'] is String) {
    try {
      if (parseDay(
        task['repeatUntil'],
      ).isBefore(parseDay(task['startDate'] ?? task['date']))) {
        return 'Repeat end must be on or after the series start.';
      }
    } catch (_) {
      return 'Choose a valid repeat end date.';
    }
  }
  return null;
}

void applyDuration(TaskData task) {
  final start = timeMinutes(task['startTime']);
  final duration = (task['durationMinutes'] as num?)?.toInt();
  if (start != null && duration != null && start + duration < 1440) {
    task['endTime'] = minutesLabel(start + duration);
  } else {
    final derived = taskDuration(task);
    if (derived != null) task['durationMinutes'] = derived;
  }
}

bool timeBlocksOverlap(TaskData a, TaskData b) {
  final as_ = timeMinutes(a['startTime']);
  final bs = timeMinutes(b['startTime']);
  final ad = taskDuration(a);
  final bd = taskDuration(b);
  return as_ != null &&
      bs != null &&
      ad != null &&
      bd != null &&
      as_ < bs + bd &&
      bs < as_ + ad;
}

DateTime mondayOf(DateTime now) =>
    DateTime(now.year, now.month, now.day - (now.weekday - 1));
int goalProgress(
  TaskData goal,
  Map<String, List<TaskData>> history,
  DateTime now,
) {
  final start = goal['period'] == 'Weekly' ? mondayOf(now) : null;
  final end = start == null
      ? null
      : DateTime(start.year, start.month, start.day + 7);
  final baseline = (goal['resetBaseline'] as Map? ?? {})
      .cast<String, dynamic>();
  var count = 0;
  for (final entry in history.entries) {
    final date = parseDay(entry.key);
    if (date.isAfter(dayOnly(now)) ||
        (start != null && (date.isBefore(start) || !date.isBefore(end!)))) {
      continue;
    }
    for (final task in entry.value) {
      final id = '${entry.key}|${taskIdentity(task)}';
      if (task['goalId'] == goal['id'] &&
          isTaskComplete(task) &&
          baseline[id] != true) {
        count++;
      }
    }
  }
  return count;
}

Map<String, bool> goalResetBaseline(
  TaskData goal,
  Map<String, List<TaskData>> history,
) => {
  for (final entry in history.entries)
    for (final task in entry.value)
      if (task['goalId'] == goal['id'] && isTaskComplete(task))
        '${entry.key}|${taskIdentity(task)}': true,
};
String _csvCell(Object? value) {
  var text = value?.toString() ?? '';
  if (RegExp(r'^\s*[=+@-]').hasMatch(text)) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}

String exportTasksCsv(Map<String, List<TaskData>> days) {
  final rows = <List<Object?>>[
    [
      'Date',
      'Task',
      'Status',
      'Category',
      'Priority',
      'Start',
      'End',
      'Duration (minutes)',
      'Repeat',
      'Tags',
      'Subtasks done',
      'Subtasks total',
    ],
  ];
  final dates = days.keys.toList()
    ..sort((a, b) => parseDay(a).compareTo(parseDay(b)));
  for (final date in dates) {
    for (final t in days[date]!) {
      final subs = taskSubtasks(t);
      rows.add([
        date,
        t['title'],
        isTaskComplete(t) ? 'Complete' : t['status'] ?? 'Not Started',
        t['category'],
        t['priority'],
        t['startTime'],
        t['endTime'],
        taskDuration(t),
        t['repeat'],
        (t['tags'] as List? ?? []).join('; '),
        subs.where((s) => s['completed'] == true).length,
        subs.length,
      ]);
    }
  }
  return '${rows.map((r) => r.map(_csvCell).join(',')).join('\r\n')}\r\n';
}
