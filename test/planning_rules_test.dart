import 'package:flutter_test/flutter_test.dart';
import 'package:TrakOn/utils/planning_rules.dart';
import 'package:TrakOn/utils/focus_clock.dart';

void main() {
  TaskData series({String repeat = 'Daily', String start = '2026-10-31'}) => {
    'recurringId': 'series-1',
    'id': 'task-1',
    'title': 'Study',
    'startDate': start,
    'date': start,
    'repeat': repeat,
    'subtasks': [
      {'id': 'step-1', 'title': 'Read', 'completed': true},
    ],
  };
  group('Recurrence rules', () {
    test(
      'Never does not generate a repeating copy',
      () => expect(
        taskRunsOnDate(series(repeat: 'Never'), DateTime(2026, 10, 31)),
        false,
      ),
    );
    test(
      'Daily never appears before its start',
      () => expect(taskRunsOnDate(series(), DateTime(2026, 10, 30)), false),
    );
    test(
      'Weekdays excludes Saturday',
      () => expect(
        taskRunsOnDate(series(repeat: 'Weekdays'), DateTime(2026, 10, 31)),
        false,
      ),
    );
    test(
      'Weekly uses original weekday',
      () => expect(
        taskRunsOnDate(series(repeat: 'Weekly'), DateTime(2026, 11, 7)),
        true,
      ),
    );
    test(
      'Custom weekdays are respected',
      () => expect(
        taskRunsOnDate({
          ...series(repeat: 'Specific Days'),
          'repeatDays': [1, 3],
        }, DateTime(2026, 11, 2)),
        true,
      ),
    );
    test(
      'Every three days uses civil dates over DST',
      () => expect(
        taskRunsOnDate({
          ...series(repeat: 'Every N Days'),
          'repeatInterval': 3,
        }, DateTime(2026, 11, 3)),
        true,
      ),
    );
    test('Every two weeks excludes intervening week', () {
      final t = {...series(repeat: 'Every N Weeks'), 'repeatInterval': 2};
      expect(taskRunsOnDate(t, DateTime(2026, 11, 7)), false);
      expect(taskRunsOnDate(t, DateTime(2026, 11, 14)), true);
    });
    test('Monthly clamps the 31st to February end', () {
      final t = series(repeat: 'Monthly', start: '2027-1-31');
      expect(taskRunsOnDate(t, DateTime(2027, 2, 28)), true);
      expect(taskRunsOnDate(t, DateTime(2027, 3, 31)), true);
      expect(taskRunsOnDate(t, DateTime(2027, 3, 28)), false);
    });
    test(
      'Leap year monthly uses February 29',
      () => expect(
        taskRunsOnDate(
          series(repeat: 'Monthly', start: '2028-1-31'),
          DateTime(2028, 2, 29),
        ),
        true,
      ),
    );
    test('Yearly leap day clamps only in original month', () {
      final t = series(repeat: 'Yearly', start: '2024-2-29');
      expect(taskRunsOnDate(t, DateTime(2027, 2, 28)), true);
      expect(taskRunsOnDate(t, DateTime(2027, 3, 1)), false);
    });
    test('Repeat until is inclusive', () {
      final t = {...series(), 'repeatUntil': '2026-11-2'};
      expect(taskRunsOnDate(t, DateTime(2026, 11, 2)), true);
      expect(taskRunsOnDate(t, DateTime(2026, 11, 3)), false);
    });
    test(
      'Empty weekday selection never generates occurrences',
      () => expect(
        taskRunsOnDate({
          ...series(repeat: 'Specific Days'),
          'repeatDays': [],
        }, DateTime(2026, 11, 2)),
        false,
      ),
    );
  });
  group('Dated task history', () {
    test('Yesterday completion cannot leak into today', () {
      final t = series();
      final output = materializeDay(
        saved: [
          {...t, 'completed': true, 'status': 'Complete'},
        ],
        templates: [t],
        date: '2026-11-1',
      );
      expect(output.single['completed'], false);
      expect(output.single['status'], 'Not Started');
    });
    test('Today completion is retained', () {
      final t = series();
      final saved = {
        ...t,
        'date': '2026-11-1',
        'status': 'Complete',
        'completed': true,
      };
      expect(
        materializeDay(
          saved: [saved],
          templates: [t],
          date: '2026-11-1',
        ).single['completed'],
        true,
      );
    });
    test('A new occurrence resets subtasks without mutating template', () {
      final t = series();
      final output = materializeDay(
        saved: [],
        templates: [t],
        date: '2026-11-1',
      );
      expect(taskSubtasks(output.single).single['completed'], false);
      expect(taskSubtasks(t).single['completed'], true);
    });
    test('Same-date subtask completion persists', () {
      final t = series();
      final saved = {...t, 'date': '2026-11-1'};
      expect(
        taskSubtasks(
          materializeDay(
            saved: [saved],
            templates: [t],
            date: '2026-11-1',
          ).single,
        ).single['completed'],
        true,
      );
    });
    test('Deleted series leaves past history intact', () {
      final t = series();
      expect(
        materializeDay(
          saved: [t],
          templates: [],
          date: '2026-10-31',
          deletedSeries: {'series-1': '2026-11-1'},
        ),
        hasLength(1),
      );
      expect(
        materializeDay(
          saved: [
            {...t, 'date': '2026-11-1'},
          ],
          templates: [],
          date: '2026-11-1',
          deletedSeries: {'series-1': '2026-11-1'},
        ),
        isEmpty,
      );
    });
    test(
      'Duplicate saved normal IDs are counted once',
      () => expect(
        materializeDay(
          saved: [
            {'id': 'a'},
            {'id': 'a'},
          ],
          templates: [],
          date: '2026-11-1',
        ),
        hasLength(1),
      ),
    );
    test(
      'Calendar date parsing rejects invalid rollover dates',
      () => expect(() => parseDay('2026-2-31'), throwsFormatException),
    );
  });
  test('Editing repeat rules does not erase saved historical completion', () {
    final original = series()..['completed'] = true;
    final updated = {
      ...original,
      'title': 'New title',
      'repeat': 'Specific Days',
      'repeatDays': [1],
    };
    final history = materializeDay(
      saved: [original],
      templates: [updated],
      date: '2026-10-31',
      asOf: DateTime(2026, 11, 1),
    );
    expect(history, hasLength(1));
    expect(history.single['completed'], true);
    expect(history.single['title'], 'Study');
  });

  group('Scheduling and export', () {
    test('24-hour and AM/PM times parse consistently', () {
      expect(timeMinutes('14:30'), 870);
      expect(timeMinutes('2:30 PM'), 870);
      expect(timeMinutes('12:00 AM'), 0);
      expect(timeMinutes('12:00 PM'), 720);
    });
    test('Bad times are rejected', () {
      expect(timeMinutes('27:00'), null);
      expect(timeMinutes('10:70 PM'), null);
    });
    test('Duration sets end time', () {
      final t = <String, dynamic>{
        'startTime': '2:30 PM',
        'durationMinutes': 45,
      };
      applyDuration(t);
      expect(t['endTime'], '3:15 PM');
    });
    test(
      'Validation rejects blocks crossing midnight',
      () => expect(
        validatePlanningTask({
          'title': 'Task',
          'date': '2026-11-1',
          'startTime': '11:30 PM',
          'durationMinutes': 60,
        }),
        isNotNull,
      ),
    );
    test('Empty names and empty repeat days are rejected', () {
      expect(validatePlanningTask({'title': ''}), isNotNull);
      expect(
        validatePlanningTask({
          'title': 'X',
          'repeat': 'Specific Days',
          'repeatDays': [],
        }),
        isNotNull,
      );
    });
    test('Overlap detection permits adjacent time blocks', () {
      final a = <String, dynamic>{
        'startTime': '9:00 AM',
        'endTime': '10:00 AM',
      };
      expect(
        timeBlocksOverlap(a, {'startTime': '10:00 AM', 'durationMinutes': 30}),
        false,
      );
      expect(
        timeBlocksOverlap(a, {'startTime': '9:30 AM', 'durationMinutes': 30}),
        true,
      );
    });
    test('CSV escapes quotes, commas and formulas', () {
      final csv = exportTasksCsv({
        '2026-11-1': [
          {
            'title': '=HYPERLINK("x")',
            'tags': ['a,b'],
          },
        ],
      });
      expect(csv, contains("'=HYPERLINK"));
      expect(csv, contains('""x""'));
      expect(csv, contains('"a,b"'));
    });
    test('CSV orders dates chronologically, not alphabetically', () {
      final csv = exportTasksCsv({
        '2026-11-10': [
          {'title': 'Later'},
        ],
        '2026-11-2': [
          {'title': 'Earlier'},
        ],
      });
      expect(csv.indexOf('Earlier'), lessThan(csv.indexOf('Later')));
    });
  });
  group('Goals', () {
    final history = <String, List<TaskData>>{
      '2026-10-25': [
        {'id': 'a', 'goalId': 'g', 'completed': true},
      ],
      '2026-10-26': [
        {'id': 'b', 'goalId': 'g', 'completed': true},
      ],
      '2026-11-1': [
        {'id': 'c', 'goalId': 'g', 'completed': true},
      ],
      '2026-11-2': [
        {'id': 'd', 'goalId': 'g', 'completed': true},
      ],
    };
    test(
      'Weekly counts Sunday through Saturday and excludes future',
      () => expect(
        goalProgress(
          {'id': 'g', 'period': 'Weekly'},
          history,
          DateTime(2026, 11, 1),
        ),
        1,
      ),
    );
    test(
      'Monday remains in the Sunday-starting week',
      () => expect(
        goalProgress(
          {'id': 'g', 'period': 'Weekly'},
          history,
          DateTime(2026, 11, 2),
        ),
        2,
      ),
    );
    test(
      'Legacy goal counts as long-term',
      () =>
          expect(goalProgress({'id': 'g'}, history, DateTime(2026, 11, 1)), 3),
    );
    test(
      'Reset ignores earlier completed occurrences but preserves history',
      () {
        final goal = <String, dynamic>{'id': 'g'};
        goal['resetBaseline'] = goalResetBaseline(goal, {
          '2026-10-26': history['2026-10-26']!,
        });
        expect(goalProgress(goal, history, DateTime(2026, 11, 1)), 2);
        expect(history['2026-10-26']!.single['completed'], true);
      },
    );
  });
  group('Focus timer', () {
    test('Deadline accounts for background elapsed time', () {
      final clock = FocusClock(durationSeconds: 1500);
      final now = DateTime(2026, 11, 1, 9);
      clock.start(now);
      expect(clock.remaining(now.add(const Duration(minutes: 20))), 300);
    });
    test('Pause and resume retain remaining time', () {
      final c = FocusClock(durationSeconds: 600);
      final now = DateTime(2026, 11, 1, 9);
      c.start(now);
      c.pause(now.add(const Duration(minutes: 2)));
      expect(c.remaining(now.add(const Duration(hours: 1))), 480);
      c.start(now.add(const Duration(hours: 1)));
      expect(c.remaining(now.add(const Duration(hours: 1, minutes: 1))), 420);
    });
    test('Process restart restores the deadline', () {
      final c = FocusClock()..start(DateTime(2026, 11, 1, 9));
      final restored = FocusClock.fromJson(c.toJson());
      expect(restored.remaining(DateTime(2026, 11, 1, 9, 10)), 900);
    });
    test('Completion is counted once', () {
      final c = FocusClock(durationSeconds: 60)
        ..start(DateTime(2026, 11, 1, 9));
      expect(c.finishIfExpired(DateTime(2026, 11, 1, 9, 2)), true);
      expect(c.finishIfExpired(DateTime(2026, 11, 1, 9, 3)), false);
      expect(c.sessions, 1);
    });
    test('Breaks do not increment focus session count', () {
      final c = FocusClock(durationSeconds: 60, mode: 'Break')
        ..start(DateTime(2026, 11, 1, 9));
      c.finishIfExpired(DateTime(2026, 11, 1, 9, 2));
      expect(c.sessions, 0);
    });
  });
}
