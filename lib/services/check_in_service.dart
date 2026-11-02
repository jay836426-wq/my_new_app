import '../utils/planning_rules.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'planning_store.dart';
import '../screens/notification_service.dart';
import '../screens/notification_preferences.dart';

class CheckInService {
  static const types = ['planning', 'goals', 'review', 'mood'];
  static String pref(String type) => 'v12_${type}Alert';
  static Future<void> apply(PlanningStore store) async {
    final master = await NotificationPreferences.notificationsEnabled();
    for (var i = 0; i < types.length; i++) {
      final type = types[i];
      final id = 9000008 + i;
      await NotificationService.cancelNotification(id);
      if (!master || store.prefs.getBool(store.key(pref(type))) != true) {
        continue;
      }
      final hour =
          store.prefs.getInt(store.key('${pref(type)}Hour')) ??
          (type == 'planning' ? 9 : 18);
      final minute = store.prefs.getInt(store.key('${pref(type)}Minute')) ?? 0;
      final now = DateTime.now();
      final weekly = type == 'goals' || type == 'review';
      final next = nextCheckInTime(now, hour, minute, saturday: weekly);
      final titles = {
        'planning': 'Plan your day',
        'goals': 'Check your goals',
        'review': 'Your weekly review',
        'mood': 'How are you feeling?',
      };
      final bodies = {
        'planning': 'Choose a few priorities in TrakOn.',
        'goals': 'Review your weekly and long-term goals.',
        'review': 'Take a moment to review your Sunday–Saturday progress.',
        'mood': 'Your optional daily mood check-in is ready.',
      };
      await NotificationService.scheduleNotification(
        id: id,
        title: titles[type]!,
        body: bodies[type]!,
        scheduledTime: next,
        matchDateTimeComponents: weekly
            ? DateTimeComponents.dayOfWeekAndTime
            : DateTimeComponents.time,
        payload: 'checkin:$type',
      );
    }
    if (!master || store.prefs.getBool(store.key('v12_focusAlert')) == false) {
      await NotificationService.cancelNotification(9000007);
      return;
    }
    final raw = store.prefs.getString(store.key('focusTimerV12'));
    if (raw != null) {
      final value = jsonDecode(raw) as Map;
      final deadline = DateTime.tryParse(value['deadline']?.toString() ?? '');
      if (deadline != null && deadline.isAfter(DateTime.now())) {
        await NotificationService.scheduleNotification(
          id: 9000007,
          title: value['mode'] == 'Break'
              ? 'Break complete'
              : 'Focus session complete',
          body: value['title']?.toString() ?? 'Your session has finished.',
          scheduledTime: deadline,
          payload: 'focus',
        );
      }
    }
  }
}
