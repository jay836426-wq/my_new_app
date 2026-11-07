import 'package:flutter_test/flutter_test.dart';
import 'package:TrakOn/utils/engagement_rules.dart';
import 'package:TrakOn/utils/planning_rules.dart';
import 'package:TrakOn/utils/motivational_quotes.dart';

void main() {
  final goal = <String, dynamic>{'id': 'g', 'period': 'Monthly', 'target': 2};
  Map<String, dynamic> complete(String id) => {
    'id': id,
    'goalId': 'g',
    'completed': true,
  };
  test('Monthly counts only this calendar month and excludes future dates', () {
    final history = {
      '2026-10-31': [complete('a')],
      '2026-11-1': [complete('b')],
      '2026-11-6': [complete('c')],
      '2026-11-7': [complete('d')],
    };
    expect(goalProgress(goal, history, DateTime(2026, 11, 6)), 2);
    expect(goalProgress(goal, history, DateTime(2026, 12, 1)), 0);
  });
  test('Leap February includes its last day but not March', () {
    final history = {
      '2028-2-29': [complete('a')],
      '2028-3-1': [complete('b')],
    };
    expect(goalProgress(goal, history, DateTime(2028, 2, 29)), 1);
  });
  test('Long term goal continues across year boundaries', () {
    final history = {
      '2026-12-31': [complete('a')],
      '2027-1-1': [complete('b')],
    };
    expect(
      goalProgress(
        {...goal, 'period': 'Long-term'},
        history,
        DateTime(2027, 1, 1),
      ),
      2,
    );
  });
  test('Reset baseline preserves dated tasks and excludes old completions', () {
    final history = {
      '2026-11-1': [complete('a')],
    };
    final reset = {...goal, 'resetBaseline': goalResetBaseline(goal, history)};
    expect(goalProgress(reset, history, DateTime(2026, 11, 6)), 0);
    history['2026-11-6'] = [complete('b')];
    expect(goalProgress(reset, history, DateTime(2026, 11, 6)), 1);
    expect(history['2026-11-1']!.single['completed'], true);
  });
  test('Monthly achievement keys change each month', () {
    expect(
      goalPeriodKey(goal, DateTime(2026, 11, 6)),
      isNot(goalPeriodKey(goal, DateTime(2026, 12, 6))),
    );
  });
  test('Weekly achievement keys group Sunday through Saturday', () {
    final weekly = {...goal, 'period': 'Weekly'};
    expect(
      goalPeriodKey(weekly, DateTime(2026, 11, 1)),
      goalPeriodKey(weekly, DateTime(2026, 11, 7)),
    );
    expect(
      goalPeriodKey(weekly, DateTime(2026, 11, 8)),
      isNot(goalPeriodKey(weekly, DateTime(2026, 11, 7))),
    );
  });
  test('Reset creates a new achievement identity', () {
    expect(
      goalPeriodKey(goal, DateTime(2026, 11, 6)),
      isNot(goalPeriodKey({...goal, 'resetAt': 'new'}, DateTime(2026, 11, 6))),
    );
  });
  test('Quiet hours spanning midnight defer to the next allowed time', () {
    expect(inQuietHours(DateTime(2026, 11, 6, 23), 22, 8), true);
    expect(inQuietHours(DateTime(2026, 11, 6, 8), 22, 8), false);
    expect(
      afterQuietHours(DateTime(2026, 11, 6, 23), 22, 8),
      DateTime(2026, 11, 7, 8),
    );
    expect(
      afterQuietHours(DateTime(2026, 11, 6, 7), 22, 8),
      DateTime(2026, 11, 6, 8),
    );
  });
  test('Daytime quiet window and disabled equal-hour window', () {
    expect(
      afterQuietHours(DateTime(2026, 11, 6, 14), 13, 16),
      DateTime(2026, 11, 6, 16),
    );
    expect(inQuietHours(DateTime(2026, 11, 6, 14), 8, 8), false);
  });
  test('Consistency counts distinct saved days not tasks', () {
    final history = {
      '2026-11-6': [complete('a'), complete('b')],
      '2026-11-5': [complete('c')],
      '2026-10-30': [complete('old')],
    };
    expect(consistentDays(history, DateTime(2026, 11, 6)), 2);
    expect(activeDayStreak(history, DateTime(2026, 11, 6)), 2);
  });
  test(
    'An unfinished current day retains yesterday streak, a gap breaks it',
    () {
      final history = {
        '2026-11-5': [complete('a')],
        '2026-11-4': [complete('b')],
      };
      expect(activeDayStreak(history, DateTime(2026, 11, 6)), 2);
      expect(activeDayStreak(history, DateTime(2026, 11, 7)), 0);
    },
  );
  test('Task check-in reflects actionable status and subtask count', () {
    expect(taskCheckInMessage({'title': 'Gym'}), contains('In Progress'));
    expect(
      taskCheckInMessage({
        'title': 'Gym',
        'status': 'In Progress',
        'subtasks': [
          {'id': 's', 'title': 'Warm up', 'completed': true},
          {'id': 't', 'title': 'Lift', 'completed': false},
        ],
      }),
      contains('1 of 2'),
    );
    expect(
      taskCheckInMessage({'title': 'Gym', 'status': 'In Progress'}),
      isNot(contains('steps checked off')),
    );
  });
  test('Quote selection is stable for a calendar day and rotates', () {
    expect(
      quoteForDay(DateTime(2026, 11, 6, 1)),
      quoteForDay(DateTime(2026, 11, 6, 23)),
    );
    expect(
      quoteForDay(DateTime(2026, 11, 6)),
      isNot(quoteForDay(DateTime(2026, 11, 7))),
    );
  });
}
