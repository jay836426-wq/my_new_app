import 'package:flutter_test/flutter_test.dart';

import '../lib/utils/recurring_reminder_plan.dart';

void main() {
  final now = DateTime(2026, 10, 2, 9); // Friday.
  Map<String, dynamic> template({
    String repeat = 'Daily',
    String priority = '🔴 High',
  }) => {
    'startDate': '2026-10-2',
    'repeat': repeat,
    'repeatDays': [1, 3, 5],
    'reminderTime': '10:00 AM',
    'endTime': '11:00 AM',
    'priority': priority,
  };
  List<RecurringReminder> plan(
    Map<String, dynamic> task, {
    Map<String, Map<String, dynamic>> occurrences = const {},
    DateTime? at,
    bool followUps = true,
  }) => buildRecurringReminderPlan(
    template: task,
    occurrences: occurrences,
    now: at ?? now,
    followUpsEnabled: followUps,
  );

  test('Completion clears every reminder for today, preserves future days', () {
    final reminders = plan(
      template(),
      occurrences: {
        '2026-10-2': {'status': 'Complete', 'completed': true},
      },
    );
    expect(reminders, hasLength(24));
    expect(reminders.every((r) => r.time.day != 2), isTrue);
    expect(reminders.map((r) => r.offset).toSet(), hasLength(24));
  });

  test('Legacy completion flag also suppresses reminders', () {
    final reminders = plan(
      template(),
      occurrences: {
        '2026-10-2': {'status': 'Not Started', 'completed': true},
      },
    );
    expect(reminders.every((r) => r.time.day != 2), isTrue);
  });

  test(
    'In progress replaces all today follow-ups with one end-time reminder',
    () {
      final reminders = plan(
        template(),
        occurrences: {
          '2026-10-2': {'status': 'In Progress'},
        },
      );
      final today = reminders.where((r) => r.time.day == 2).toList();
      expect(today, hasLength(1));
      expect(today.single.isEndTime, isTrue);
      expect(today.single.time, DateTime(2026, 10, 2, 11));
    },
  );

  test('A future completed occurrence stays silent after rebuild', () {
    final reminders = plan(
      template(),
      occurrences: {
        '2026-10-3': {'status': 'Complete'},
      },
    );
    expect(reminders.every((r) => r.time.day != 3), isTrue);
    expect(reminders.any((r) => r.time.day == 2), isTrue);
  });

  test('Reopening restores only follow-ups still in the future', () {
    final reminders = plan(template(), at: DateTime(2026, 10, 2, 10, 20));
    final today = reminders.where((r) => r.time.day == 2).toList();
    expect(today.map((r) => r.time.minute).toList(), [30, 0]);
    expect(today.last.time.hour, 11);
  });

  test('Weekdays never generate weekend occurrences', () {
    final reminders = plan(template(repeat: 'Weekdays'));
    expect(reminders, hasLength(28));
    expect(reminders.every((r) => r.time.weekday <= 5), isTrue);
  });

  test('Weekly recurrence retains the original weekday across seven weeks', () {
    final reminders = plan(template(repeat: 'Weekly', priority: '🟢 Low'));
    expect(reminders, hasLength(7));
    expect(reminders.every((r) => r.time.weekday == DateTime.friday), isTrue);
    expect(reminders.last.time, DateTime(2026, 11, 13, 10));
  });

  test('Specific days respect the selected weekday list', () {
    final reminders = plan(template(repeat: 'Specific Days'));
    expect(reminders.every((r) => [1, 3, 5].contains(r.time.weekday)), isTrue);
  });

  test('Future start dates are honored', () {
    final task = template()..['startDate'] = '2026-10-20';
    expect(plan(task).first.time, DateTime(2026, 10, 20, 10));
  });

  test('Start time overrides reminder time and medium gets one follow-up', () {
    final task = template(priority: '🟡 Medium')..['startTime'] = '2:00 PM';
    final reminders = plan(task);
    expect(reminders, hasLength(14));
    expect(reminders.first.time.hour, 14);
    expect(reminders[1].time.minute, 30);
  });

  test('Disabled follow-ups leave the main reminder', () {
    expect(plan(template(), followUps: false), hasLength(7));
  });

  test(
    'Missing start/reminder time still allows an in-progress end reminder',
    () {
      final task = template()..remove('reminderTime');
      final reminders = plan(
        task,
        occurrences: {
          '2026-10-2': {'status': 'In Progress'},
        },
      );
      expect(reminders, hasLength(1));
      expect(reminders.single.isEndTime, isTrue);
    },
  );

  test('Empty weekdays and nonrecurring templates have no reminders', () {
    expect(
      plan(template(repeat: 'Specific Days')..['repeatDays'] = []),
      isEmpty,
    );
    expect(plan(template(repeat: 'Never')), isEmpty);
  });
}
