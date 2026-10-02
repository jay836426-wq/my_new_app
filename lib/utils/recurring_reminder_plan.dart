/// A dated reminder belonging to one occurrence of a recurring task.
class RecurringReminder {
  const RecurringReminder({
    required this.offset,
    required this.time,
    required this.isFollowUp,
    this.isEndTime = false,
  });

  final int offset;
  final DateTime time;
  final bool isFollowUp;
  final bool isEndTime;
}

String reminderDateKey(DateTime date) =>
    '${date.year}-${date.month}-${date.day}';

DateTime _dateFromKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

DateTime? _timeOnDate(dynamic value, DateTime date) {
  if (value is! String) return null;
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour < 1 || hour > 12 || minute > 59) return null;
  hour %= 12;
  if (match.group(3)!.toUpperCase() == 'PM') hour += 12;
  return DateTime(date.year, date.month, date.day, hour, minute);
}

bool _runsOnDate(Map<String, dynamic> template, DateTime date, DateTime start) {
  if (date.isBefore(start)) return false;
  switch (template['repeat']) {
    case 'Daily':
      return true;
    case 'Weekdays':
      return date.weekday <= DateTime.friday;
    case 'Weekly':
      return date.weekday == start.weekday;
    case 'Specific Days':
      return (template['repeatDays'] as List? ?? []).contains(date.weekday);
    default:
      return false;
  }
}

/// Uses dated, one-shot requests so completing an occurrence can actually
/// remove its follow-ups on iOS. Time-only repeating requests ignore the date.
/// Queue seven occurrences (up to 28 requests); refill when Home opens/resumes.
List<RecurringReminder> buildRecurringReminderPlan({
  required Map<String, dynamic> template,
  required Map<String, Map<String, dynamic>> occurrences,
  required DateTime now,
  required bool followUpsEnabled,
}) {
  final startKey = template['startDate'] ?? template['date'];
  if (startKey is! String) return [];
  final start = _dateFromKey(startKey);
  final today = DateTime(now.year, now.month, now.day);
  var date = start.isAfter(today) ? start : today;
  final plan = <RecurringReminder>[];
  var slot = 0;

  // Seven weekly occurrences fit within 49 days. Bound invalid repeat rules.
  for (var searched = 0; searched < 49 && slot < 7; searched++) {
    if (_runsOnDate(template, date, start)) {
      final occurrence = occurrences[reminderDateKey(date)];
      final status = occurrence?['completed'] == true
          ? 'Complete'
          : occurrence?['status']?.toString() ?? 'Not Started';
      if (status == 'In Progress') {
        final end = _timeOnDate(template['endTime'], date);
        if (end != null && end.isAfter(now)) {
          plan.add(
            RecurringReminder(
              offset: slot * 4,
              time: end,
              isFollowUp: false,
              isEndTime: true,
            ),
          );
        }
      } else if (status != 'Complete') {
        final time =
            _timeOnDate(template['startTime'], date) ??
            _timeOnDate(template['reminderTime'], date);
        if (time != null) {
          final offsets = <Duration>[Duration.zero];
          if (followUpsEnabled && template['priority'] == '🔴 High') {
            offsets.addAll(const [
              Duration(minutes: 15),
              Duration(minutes: 30),
              Duration(minutes: 60),
            ]);
          } else if (followUpsEnabled && template['priority'] == '🟡 Medium') {
            offsets.add(const Duration(minutes: 30));
          }
          for (var index = 0; index < offsets.length; index++) {
            final reminder = time.add(offsets[index]);
            if (reminder.isAfter(now)) {
              plan.add(
                RecurringReminder(
                  offset: slot * 4 + index,
                  time: reminder,
                  isFollowUp: index > 0,
                ),
              );
            }
          }
        }
      }
      slot++;
    }
    // Calendar arithmetic preserves local dates across daylight-saving changes.
    date = DateTime(date.year, date.month, date.day + 1);
  }
  return plan;
}
