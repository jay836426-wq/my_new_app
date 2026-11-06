import 'package:flutter_test/flutter_test.dart';
import 'package:TrakOn/utils/mood_rules.dart';
import 'package:TrakOn/utils/planning_rules.dart';

void main() {
  test('A saved mood removes only its date from pending reminders', () {
    final dates = pendingMoodReminders(DateTime(2026, 11, 1, 9), 18, 0, {
      '2026-11-1': {'mood': 3},
    });
    expect(dates.length, 6);
    expect(dates.first, DateTime(2026, 11, 2, 18));
  });
  test('Expired reminder does not fire late', () {
    expect(
      pendingMoodReminders(DateTime(2026, 11, 1, 19), 18, 0, {}).first,
      DateTime(2026, 11, 2, 18),
    );
  });
  test('Reminders retain wall time and unique days across DST', () {
    final dates = pendingMoodReminders(DateTime(2026, 10, 31, 9), 18, 15, {});
    expect(dates.map(dayKey).toSet().length, 7);
    expect(dates.every((d) => d.hour == 18 && d.minute == 15), true);
  });
  test('Deleting a check-in makes the future reminder eligible again', () {
    expect(
      pendingMoodReminders(DateTime(2026, 11, 1, 9), 18, 0, {}).first,
      DateTime(2026, 11, 1, 18),
    );
  });
}
