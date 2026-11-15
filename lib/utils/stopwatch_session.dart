import 'dart:math' as math;

String? stopwatchTaskDate(String? date) {
  if (date == null) return null;
  final pieces = date.split('-');
  if (pieces.length != 3) return date;
  final values = pieces.map(int.tryParse).toList();
  if (values.any((v) => v == null)) return date;
  return '${values[0]}-${values[1]}-${values[2]}';
}

String stopwatchTime(int milliseconds, {bool centiseconds = false}) {
  final seconds = math.max(0, milliseconds ~/ 1000);
  final base =
      '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${((seconds ~/ 60) % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  return centiseconds
      ? '$base.${((math.max(0, milliseconds) % 1000) ~/ 10).toString().padLeft(2, '0')}'
      : base;
}

class StopwatchSession {
  StopwatchSession({
    required this.id,
    required this.title,
    required this.createdAt,
    this.taskId,
    this.taskDate,
    this.taskTitle,
    this.startedAt,
    this.endedAt,
    this.accumulatedMs = 0,
    this.reminderMinutes = 60,
    List<int>? laps,
  }) : laps = laps ?? [];
  final String id;
  String title;
  final String? taskId, taskDate, taskTitle;
  final DateTime createdAt;
  DateTime? startedAt, endedAt;
  int accumulatedMs;
  int? reminderMinutes;
  final List<int> laps;
  bool get running => startedAt != null;
  bool get finalizing => endedAt != null;
  int elapsed(DateTime now) => math.max(
    laps.isEmpty ? 0 : laps.last,
    accumulatedMs +
        (startedAt == null
            ? 0
            : math.max(
                0,
                now.toUtc().difference(startedAt!.toUtc()).inMilliseconds,
              )),
  );
  void start(DateTime now) {
    if (finalizing) throw StateError('Finish saving this session first.');
    startedAt ??= now.toUtc();
  }

  void pause(DateTime now) {
    accumulatedMs = elapsed(now);
    startedAt = null;
  }

  bool lap(DateTime now) {
    if (!running || finalizing) return false;
    if (laps.length >= 200) {
      throw StateError('This session already has 200 laps.');
    }
    final total = elapsed(now);
    if (total <= (laps.isEmpty ? 0 : laps.last)) return false;
    laps.add(total);
    return true;
  }

  bool matchesTask(String id, String date) =>
      taskId == id && stopwatchTaskDate(taskDate) == stopwatchTaskDate(date);
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'taskId': taskId,
    'taskDate': taskDate,
    'taskTitle': taskTitle,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'endedAt': endedAt?.toUtc().toIso8601String(),
    'accumulatedMs': accumulatedMs,
    'reminderMinutes': reminderMinutes,
    'laps': laps,
  };
  factory StopwatchSession.fromJson(Map<String, dynamic> v) => StopwatchSession(
    id: v['id'].toString(),
    title: v['title']?.toString() ?? 'Stopwatch',
    createdAt: DateTime.parse(v['createdAt'] as String),
    taskId: v['taskId'] as String?,
    taskDate: v['taskDate'] as String?,
    taskTitle: v['taskTitle'] as String?,
    startedAt: DateTime.tryParse(v['startedAt']?.toString() ?? ''),
    endedAt: DateTime.tryParse(v['endedAt']?.toString() ?? ''),
    accumulatedMs: math.max(0, (v['accumulatedMs'] as num?)?.toInt() ?? 0),
    reminderMinutes: v['reminderMinutes'] == null
        ? null
        : ((v['reminderMinutes'] as num).toInt()).clamp(1, 240),
    laps: (v['laps'] as List? ?? []).map((n) => (n as num).toInt()).toList(),
  );
}

/// Only active (not paused) time counts toward the next three check-ins.
List<DateTime> stopwatchReminderTimes(StopwatchSession s, DateTime now) {
  final interval = s.reminderMinutes;
  if (!s.running || s.finalizing || interval == null || interval <= 0) {
    return [];
  }
  final width = interval * 60000;
  final elapsed = s.elapsed(now);
  final next = elapsed ~/ width + 1;
  return [
    for (var i = 0; i < 3; i++)
      now.add(Duration(milliseconds: (next + i) * width - elapsed)),
  ];
}
