import 'planning_rules.dart';

bool inQuietHours(DateTime time, int start, int end) {
  if (start == end) return false;
  final hour = time.hour;
  return start < end
      ? hour >= start && hour < end
      : hour >= start || hour < end;
}

DateTime afterQuietHours(DateTime time, int start, int end) {
  if (!inQuietHours(time, start, end)) return time;
  final sameDay = start < end || time.hour < end;
  return DateTime(time.year, time.month, time.day + (sameDay ? 0 : 1), end);
}

int activeDayStreak(Map<String, List<TaskData>> history, DateTime now) {
  var date = dayOnly(now);
  bool done(DateTime d) => (history[dayKey(d)] ?? []).any(isTaskComplete);
  if (!done(date)) date = calendarDay(date, -1);
  var count = 0;
  while (done(date)) {
    count++;
    date = calendarDay(date, -1);
  }
  return count;
}

int consistentDays(Map<String, List<TaskData>> history, DateTime now) =>
    List.generate(
      7,
      (i) => calendarDay(now, -i),
    ).where((d) => (history[dayKey(d)] ?? []).any(isTaskComplete)).length;
String goalPeriodKey(TaskData goal, DateTime now) {
  final period = goal['period'];
  final date = period == 'Weekly'
      ? dayKey(sundayOf(now))
      : period == 'Monthly'
      ? '${now.year}-${now.month}'
      : 'lifetime';
  return '${goal['id']}|${goal['resetAt'] ?? 'initial'}|$period|$date';
}

String taskCheckInMessage(TaskData task) {
  final title = task['title']?.toString() ?? 'your task';
  if (task['status'] == 'In Progress') {
    final subs = taskSubtasks(task);
    return subs.isEmpty
        ? 'How is “$title” going? Keep focusing, or mark it complete when you are done.'
        : 'How is “$title” going? ${subs.where((s) => s['completed'] == true).length} of ${subs.length} steps checked off. Update your next step.';
  }
  return 'Have you started “$title” yet? Mark it In Progress, or check it off if you have finished.';
}
