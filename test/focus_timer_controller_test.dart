import 'package:flutter_test/flutter_test.dart';
import 'package:TrakOn/services/focus_timer_controller.dart';
import 'package:TrakOn/services/focus_alarm_bridge.dart';
import 'package:TrakOn/services/planning_store.dart';
import 'package:TrakOn/utils/focus_clock.dart';
import 'planning_store_test.dart' show MemoryPlanningPreferences;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late MemoryPlanningPreferences prefs;
  late PlanningStore store;
  late FocusTimerController timer;
  late List<FocusClock> scheduled;
  late int cancelled;
  var signedIn = true;
  FocusTimerController make() => FocusTimerController.testing(
    store,
    ownerCheck: () => signedIn,
    now: () => now,
    schedule: (clock, _) async {
      scheduled.add(clock);
    },
    cancel: () async {
      cancelled++;
    },
  );
  setUp(() async {
    now = DateTime(2026, 11, 15, 9);
    signedIn = true;
    prefs = MemoryPlanningPreferences({});
    store = PlanningStore(uid: 'timer-test', prefs: prefs);
    scheduled = [];
    cancelled = 0;
    timer = make();
    await timer.load();
  });
  tearDown(() => timer.dispose());
  test(
    'renaming an active session updates its alert without moving its deadline',
    () async {
      await timer.configure('Focus', minutes: 10);
      await timer.start();
      final deadline = timer.clock!.deadline;
      now = now.add(const Duration(minutes: 2));
      await timer.rename('Study biology');
      expect(timer.clock!.deadline, deadline);
      expect(timer.remaining, 480);
      expect(scheduled.last.title, 'Study biology');
      expect(scheduled.last.deadline, deadline?.toUtc());
    },
  );
  test(
    'pause cancels alarm, resume schedules only the remaining time',
    () async {
      await timer.configure('Focus', minutes: 10);
      await timer.start();
      now = now.add(const Duration(minutes: 3));
      final before = cancelled;
      await timer.pause();
      expect(cancelled, greaterThan(before));
      expect(timer.remaining, 420);
      now = now.add(const Duration(minutes: 30));
      await timer.start();
      expect(
        scheduled.last.deadline,
        now.add(const Duration(minutes: 7)).toUtc(),
      );
    },
  );
  test('focus and break keep different names and durations', () async {
    await timer.configure('Focus', minutes: 45);
    await timer.rename('Deep work');
    await timer.configure('Break', minutes: 5);
    await timer.rename('Rest from studying');
    await timer.configure('Focus');
    expect(timer.clock!.durationSeconds, 2700);
    expect(timer.sessionName, 'Deep work');
    await timer.configure('Break');
    expect(timer.clock!.durationSeconds, 300);
    expect(timer.sessionName, 'Rest from studying');
  });
  test('restoring an expired focus counts it exactly once', () async {
    await timer.configure('Focus', minutes: 1);
    await timer.start();
    timer.dispose();
    now = now.add(const Duration(minutes: 2));
    timer = make();
    await timer.load();
    expect(timer.complete, isTrue);
    expect(timer.clock!.sessions, 1);
    timer.dispose();
    timer = make();
    await timer.load();
    expect(timer.clock!.sessions, 1);
  });
  test('a completed break does not increment focus sessions', () async {
    await timer.configure('Break', minutes: 1);
    await timer.start();
    timer.dispose();
    now = now.add(const Duration(minutes: 2));
    timer = make();
    await timer.load();
    expect(timer.complete, isTrue);
    expect(timer.clock!.sessions, 0);
  });
  test(
    'Stop cancels the ending alert; next phase receives a fresh deadline',
    () async {
      await timer.configure('Focus', minutes: 1);
      await timer.start();
      now = now.add(const Duration(minutes: 2));
      await timer.dismiss();
      expect(timer.clock!.running, isFalse);
      expect(timer.clock!.sessions, 1);
      await timer.configure('Break', startImmediately: true);
      expect(scheduled.last.mode, 'Break');
      expect(
        scheduled.last.deadline,
        now.add(const Duration(minutes: 5)).toUtc(),
      );
      final before = cancelled;
      await timer.reset();
      expect(cancelled, greaterThan(before));
      expect(timer.clock!.running, isFalse);
    },
  );
  test(
    'changing account prevents old controller from scheduling an alarm',
    () async {
      signedIn = false;
      await timer.start();
      expect(scheduled, isEmpty);
    },
  );
  test(
    'opening a different task preserves the running session name and deadline',
    () async {
      await timer.rename('Current task');
      await timer.start();
      final deadline = timer.clock!.deadline;
      await timer.nameFromTask('Different task');
      expect(timer.sessionName, 'Current task');
      expect(timer.clock!.deadline, deadline);
    },
  );
  test(
    'an immediately paused session remains active on Home after restart',
    () async {
      await timer.start();
      await timer.pause();
      expect(timer.paused, isTrue);
      timer.dispose();
      timer = make();
      await timer.load();
      expect(timer.paused, isTrue);
      await timer.reset();
      expect(timer.paused, isFalse);
    },
  );
  test('focus and break route to distinct custom sound files', () {
    expect(
      FocusAlarmBridge.soundFor('Focus session complete'),
      'trakon_focus.wav',
    );
    expect(FocusAlarmBridge.soundFor('Break complete'), 'trakon_break.wav');
  });
}
