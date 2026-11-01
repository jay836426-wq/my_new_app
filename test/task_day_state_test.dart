import 'package:flutter_test/flutter_test.dart';
import 'package:TrakOn/utils/task_day_state.dart';

void main() {
  const today = '2026-11-1';
  const yesterday = '2026-10-31';
  final completed = <String, dynamic>{
    'recurringId': 'daily-1',
    'date': yesterday,
    'completed': true,
    'status': 'Complete',
  };

  test('Yesterday local cache stays assigned to yesterday before backup', () {
    expect(
      activeTaskCacheDate(
        today: today,
        localLastActiveDate: yesterday,
        hasLocalTasks: true,
        cachedTasks: [completed],
      ),
      yesterday,
    );
  });
  test('Missing cache restored for today does not inherit old active date', () {
    expect(
      activeTaskCacheDate(
        today: today,
        localLastActiveDate: yesterday,
        hasLocalTasks: false,
        cachedTasks: [],
      ),
      today,
    );
  });
  test('Legacy cache with no marker can recover its date from tasks', () {
    expect(
      activeTaskCacheDate(
        today: today,
        localLastActiveDate: null,
        hasLocalTasks: true,
        cachedTasks: [completed],
      ),
      yesterday,
    );
  });
  test('Empty cache with no marker starts today', () {
    expect(
      activeTaskCacheDate(
        today: today,
        localLastActiveDate: null,
        hasLocalTasks: true,
        cachedTasks: [],
      ),
      today,
    );
  });
  test('Today cache preserves its ownership', () {
    expect(
      activeTaskCacheDate(
        today: today,
        localLastActiveDate: today,
        hasLocalTasks: true,
        cachedTasks: [],
      ),
      today,
    );
  });
  test('A recurring task cannot inherit yesterday completion on today', () {
    expect(
      recurringOccurrenceForDate(
        savedTasks: [completed],
        recurringId: 'daily-1',
        date: today,
      ),
      isNull,
    );
  });
  test('Historical completion remains available for its original date', () {
    expect(
      recurringOccurrenceForDate(
        savedTasks: [completed],
        recurringId: 'daily-1',
        date: yesterday,
      )?['completed'],
      isTrue,
    );
  });
  test('Finds the correct date even when the wrong date appears first', () {
    final current = {
      ...completed,
      'date': today,
      'completed': false,
      'status': 'In Progress',
    };
    expect(
      recurringOccurrenceForDate(
        savedTasks: [completed, current],
        recurringId: 'daily-1',
        date: today,
      )?['status'],
      'In Progress',
    );
  });
  test('Undated legacy occurrence retains status under its storage date', () {
    final legacy = Map<String, dynamic>.from(completed)..remove('date');
    expect(
      recurringOccurrenceForDate(
        savedTasks: [legacy],
        recurringId: 'daily-1',
        date: today,
      )?['completed'],
      isTrue,
    );
  });
  test('Different series does not inherit completion', () {
    expect(
      recurringOccurrenceForDate(
        savedTasks: [completed],
        recurringId: 'daily-2',
        date: yesterday,
      ),
      isNull,
    );
  });
  test('Carry over excludes recurring and completed tasks', () {
    final pending = <String, dynamic>{'title': 'Call', 'completed': false};
    expect(
      tasksEligibleForCarryOver([
        completed,
        {...completed, 'completed': false, 'status': 'In Progress'},
        {'title': 'Done', 'completed': true},
        {'title': 'Legacy done', 'status': 'Complete'},
        pending,
      ]),
      [pending],
    );
  });
  test('Carry over returns copies without modifying historical tasks', () {
    final original = <String, dynamic>{'title': 'Call', 'date': yesterday};
    final carried = tasksEligibleForCarryOver([original]);
    carried.single['date'] = today;
    expect(original['date'], yesterday);
  });
}
