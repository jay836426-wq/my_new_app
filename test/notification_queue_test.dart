import 'package:flutter_test/flutter_test.dart';
import 'package:TrakOn/utils/notification_queue.dart';

void main() {
  final now = DateTime(2026, 11, 14, 12);
  PlannedAlert task(int i) => PlannedAlert(
    id: i,
    title: 'Task',
    body: '',
    at: now.add(Duration(minutes: i + 1)),
    payload: 'task:$i',
  );
  PlannedAlert extra(int id, String payload, int minutes) => PlannedAlert(
    id: id,
    title: 'Check-in',
    body: '',
    at: now.add(Duration(minutes: minutes)),
    payload: payload,
  );
  test(
    '100 task requests cannot crowd out mood, morning, midday and timer',
    () {
      final alerts = [
        for (var i = 0; i < 100; i++) task(i),
        extra(9000012, 'checkin:mood', 80),
        extra(9010000, 'encouragement:Morning', 90),
        extra(9010001, 'encouragement:Midday', 100),
        extra(9000007, 'focus', 120),
      ];
      final selected = chooseQueuedAlerts(alerts, now);
      expect(selected.where((a) => a.isTask).length, 32);
      expect(
        selected.map((a) => a.id),
        containsAll([9000012, 9010000, 9010001, 9000007]),
      );
      expect(selected.length, lessThanOrEqualTo(60));
    },
  );
  test('nearest tasks win even when input order is reversed', () {
    final selected = chooseQueuedAlerts([
      for (var i = 99; i >= 0; i--) task(i),
    ], now);
    expect(
      selected.map((a) => a.id),
      orderedEquals(List.generate(32, (i) => i)),
    );
  });
  test(
    'unknown older requests consume space and are never selected for deletion',
    () {
      final selected = chooseQueuedAlerts(
        [for (var i = 0; i < 100; i++) task(i)],
        now,
        unknownCount: 55,
      );
      expect(selected.length, 5);
      expect(chooseQueuedAlerts([task(1)], now, unknownCount: 64), isEmpty);
    },
  );
  test('past one-shots expire but repeating alerts survive', () {
    final old = PlannedAlert(
      id: 1,
      title: '',
      body: '',
      at: now.subtract(const Duration(days: 2)),
    );
    final repeating = PlannedAlert(
      id: 9000008,
      title: '',
      body: '',
      at: old.at,
      repeat: 'time',
    );
    expect(chooseQueuedAlerts([old, repeating], now).map((a) => a.id), [
      9000008,
    ]);
  });
  test('optional horizon is bounded without using timer reserve', () {
    final selected = chooseQueuedAlerts([
      for (var i = 0; i < 39; i++)
        extra(9010000 + i, 'encouragement:Morning', i + 1),
      for (var i = 0; i < 100; i++) task(i),
      extra(9000007, 'focus', 1000),
    ], now);
    expect(selected.where((a) => a.isOptional).length, 24);
    expect(selected.any((a) => a.id == 9000007), isTrue);
    expect(selected.length, 57);
  });
  test(
    'cancelled intent cannot be selected; freeing room promotes next task',
    () {
      final saved = [for (var i = 0; i < 40; i++) task(i)];
      saved.removeWhere((a) => a.id == 0);
      final selected = chooseQueuedAlerts(saved, now);
      expect(selected.any((a) => a.id == 0), isFalse);
      expect(selected.any((a) => a.id == 32), isTrue);
    },
  );
  test('overflow intents survive a persistence round trip', () {
    final saved = [for (var i = 0; i < 100; i++) task(i)];
    final restored = saved
        .map((a) => PlannedAlert.fromJson(a.toJson()))
        .toList();
    expect(restored.length, 100);
    expect(
      chooseQueuedAlerts(restored, now).map((a) => a.id),
      chooseQueuedAlerts(saved, now).map((a) => a.id),
    );
  });
  test('stopwatch check-ins keep a slot alongside task and mood alerts', () {
    final selected = chooseQueuedAlerts([
      for (var i = 0; i < 100; i++) task(i),
      extra(9020000, 'stopwatch:gym', 80),
      extra(9000012, 'checkin:mood', 90),
    ], now);
    expect(selected.map((a) => a.id), containsAll([9020000, 9000012]));
    expect(selected.length, lessThanOrEqualTo(60));
  });
}
