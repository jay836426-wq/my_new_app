import 'package:flutter_test/flutter_test.dart';
import 'package:TrakOn/utils/stopwatch_session.dart';

void main() {
  final start = DateTime.utc(2026, 11, 15, 9);
  StopwatchSession session({int? reminder = 60}) => StopwatchSession(
    id: 's',
    title: 'Gym',
    createdAt: start,
    taskId: 'gym',
    taskDate: '2026-11-15',
    taskTitle: 'Gym',
    reminderMinutes: reminder,
  );
  test(
    'background and restart elapsed time comes from the saved timestamp',
    () {
      final s = session()..start(start);
      final restored = StopwatchSession.fromJson(s.toJson());
      expect(
        restored.elapsed(start.add(const Duration(hours: 2, minutes: 15))),
        8100000,
      );
      expect(restored.matchesTask('gym', '2026-11-15'), true);
    },
  );
  test('pause and resume exclude time spent paused', () {
    final s = session()..start(start);
    s.pause(start.add(const Duration(minutes: 20)));
    s.start(start.add(const Duration(hours: 1)));
    expect(s.elapsed(start.add(const Duration(hours: 1, minutes: 5))), 1500000);
  });
  test('lap splits and cumulative elapsed survive a round trip', () {
    final s = session()..start(start);
    s.lap(start.add(const Duration(seconds: 10)));
    s.lap(start.add(const Duration(seconds: 25)));
    final restored = StopwatchSession.fromJson(s.toJson());
    expect(restored.laps, [10000, 25000]);
    expect(restored.laps[1] - restored.laps[0], 15000);
    expect(s.lap(start.add(const Duration(seconds: 25))), false);
  });
  test(
    'check-ins count active minutes and schedule at most three future alerts',
    () {
      final s = session(reminder: 1)..start(start);
      s.pause(start.add(const Duration(seconds: 45)));
      expect(stopwatchReminderTimes(s, start), isEmpty);
      final resumed = start.add(const Duration(hours: 1));
      s.start(resumed);
      final plan = stopwatchReminderTimes(s, resumed);
      expect(plan, [
        resumed.add(const Duration(seconds: 15)),
        resumed.add(const Duration(seconds: 75)),
        resumed.add(const Duration(seconds: 135)),
      ]);
    },
  );
  test(
    'reminders never stop the stopwatch and renew from the next interval',
    () {
      final s = session()..start(start);
      final now = start.add(const Duration(hours: 4, minutes: 30));
      expect(
        stopwatchReminderTimes(s, now).first,
        start.add(const Duration(hours: 5)),
      );
      expect(s.running, true);
      expect(s.elapsed(now), 16200000);
    },
  );
  test('off and finalizing sessions have no check-in plan', () {
    final off = session(reminder: null)..start(start);
    expect(stopwatchReminderTimes(off, start), isEmpty);
    final s = session()..start(start);
    s.pause(start.add(const Duration(minutes: 1)));
    s.endedAt = start.add(const Duration(minutes: 1));
    expect(stopwatchReminderTimes(s, start), isEmpty);
    expect(() => s.start(start), throwsStateError);
  });
  test('linked recurring tasks are scoped to their occurrence date', () {
    final s = session();
    expect(s.matchesTask('gym', '2026-11-16'), false);
    expect(s.matchesTask('other', '2026-11-15'), false);
    final old = StopwatchSession(
      id: 's',
      title: 'Gym',
      createdAt: start,
      taskId: 'gym',
      taskDate: '2026-11-05',
    );
    expect(old.matchesTask('gym', '2026-11-5'), true);
  });
  test('duration formatting supports hours and clamps negative input', () {
    expect(stopwatchTime(3661000), '01:01:01');
    expect(stopwatchTime(-20), '00:00:00');
    expect(stopwatchTime(61234, centiseconds: true), '00:01:01.23');
  });
  test(
    'clock rollback cannot produce a negative elapsed time or lap split',
    () {
      final s = session()..start(start);
      s.lap(start.add(const Duration(minutes: 1)));
      expect(s.elapsed(start.subtract(const Duration(minutes: 1))), 60000);
      expect(s.lap(start.subtract(const Duration(minutes: 1))), false);
    },
  );
}
