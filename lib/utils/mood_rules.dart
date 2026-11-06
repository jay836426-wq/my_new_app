import 'planning_rules.dart';

const moodLabels = ['Very low', 'Low', 'Okay', 'Good', 'Great'];
const moodFaces = ['😞', '🙁', '😐', '🙂', '😄'];

/// One dated reminder per day, so saving today's entry can cancel only today.
List<DateTime> pendingMoodReminders(
  DateTime now,
  int hour,
  int minute,
  Map<String, dynamic> entries,
) {
  return [
        for (var i = 0; i < 7; i++)
          DateTime(now.year, now.month, now.day + i, hour, minute),
      ]
      .where((date) => date.isAfter(now) && !entries.containsKey(dayKey(date)))
      .toList();
}
