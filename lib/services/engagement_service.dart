import '../utils/motivational_quotes.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/planning_rules.dart';
import '../utils/engagement_rules.dart';
import '../screens/notification_preferences.dart';
import '../screens/notification_service.dart';
import 'planning_store.dart';

/// Opt-in local encouragement. Task due-time and timer alerts remain separate.
class EngagementService {
  static Future<void> _pending = Future.value();
  static final Map<String, Map<String, List<TaskData>>> _knownHistory = {};
  static Future<void> refresh(
    PlanningStore store, {
    bool notifications = true,
    Map<String, List<TaskData>>? historySnapshot,
  }) {
    if (historySnapshot != null) {
      _knownHistory[store.uid] = {
        for (final e in historySnapshot.entries)
          e.key: e.value.map(copyTask).toList(),
      };
    }
    final next = _pending
        .catchError((Object _) {})
        .then((_) => _refresh(store, notifications));
    _pending = next;
    return next;
  }

  static const base = 9010000;
  static bool owner(PlanningStore s) =>
      FirebaseAuth.instance.currentUser?.uid == s.uid;
  static Future<void> _refresh(PlanningStore s, bool notifications) async {
    if (!owner(s)) return;
    final history = <String, List<TaskData>>{};
    for (final key in s.prefs.getKeys()) {
      if (!key.startsWith(s.key('tasks_'))) continue;
      final date = key.substring(s.key('tasks_').length);
      try {
        parseDay(date);
        history[date] = (jsonDecode(s.prefs.getString(key) ?? '[]') as List)
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();
      } catch (_) {
        continue;
      }
    }
    for (final entry
        in (_knownHistory[s.uid] ?? <String, List<TaskData>>{}).entries) {
      history.putIfAbsent(entry.key, () => entry.value);
    }
    final now = DateTime.now();
    final today = dayKey(now);
    final templates = await s.listState('recurringTasks');
    final tombstoneRaw = s.prefs.getString(s.key('deletedSeries'));
    final tombstones = tombstoneRaw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(tombstoneRaw) as Map);
    for (final date in history.keys.toList()) {
      history[date] = materializeDay(
        saved: history[date]!,
        templates: templates,
        date: date,
        deletedSeries: tombstones,
      );
    }
    history[today] = await s.readDay(today);
    final goals = await s.listState('goals');
    final achievements = await s.listState('goalAchievementsV13');
    bool changed = false;
    for (final goal in goals) {
      // Recover past period achievements from dated task history too.
      final dates = <String, DateTime>{};
      for (final date in [...history.keys, today]) {
        final parsed = parseDay(date);
        if (parsed.isAfter(dayOnly(now))) continue;
        final key = goalPeriodKey(goal, parsed);
        if (dates[key] == null || parsed.isAfter(dates[key]!)) {
          dates[key] = parsed;
        }
      }
      for (final entry in dates.entries) {
        if (achievements.any((a) => a['id'] == entry.key)) continue;
        final at = entry.value;
        final count = goalProgress(goal, history, at);
        final target = (goal['target'] as num?)?.toInt() ?? 1;
        if (count < target) continue;
        achievements.add({
          'id': entry.key,
          'goalId': goal['id'],
          'title': goal['title'],
          'period': goal['period'] ?? 'Long-term',
          'target': target,
          'count': count,
          'periodDate': dayKey(at),
          'recordedAt': now.toUtc().toIso8601String(),
          'current': entry.key == goalPeriodKey(goal, now),
        });
        changed = true;
      }
    }
    if (changed) await s.saveState('goalAchievementsV13', achievements);
    if (!notifications || !owner(s)) return;
    // Clear only this feature's future alerts; never cancel timer/task/mood IDs.
    for (var i = 0; i < 39; i++) {
      await NotificationService.cancelNotification(base + i);
    }
    if (!await NotificationPreferences.notificationsEnabled()) {
      await NotificationService.cancelNotification(base + 40);
      return;
    }
    final enabled = s.prefs.getBool(s.key('engagementEnabled')) ?? false;
    if (!enabled) {
      await NotificationService.cancelNotification(base + 40);
      if (await NotificationPreferences.dailyMotivationEnabled()) {
        await NotificationService.scheduleDailyMotivationalNotification(
          hour: await NotificationPreferences.motivationHour(),
          minute: await NotificationPreferences.motivationMinute(),
        );
      }
      return;
    }
    if (s.prefs.getBool(s.key('engagementMorning')) == true) {
      await NotificationService.cancelNotification(
        NotificationService.motivationalNotificationId,
      );
    }
    if (s.prefs.getBool(s.key('engagementRecognition')) ?? true) {
      await NotificationService.cancelNotification(
        NotificationService.streakNotificationId,
      );
    }
    final quiet = s.prefs.getBool(s.key('engagementQuiet')) ?? true;
    final quietStart = s.prefs.getInt(s.key('engagementQuietStart')) ?? 22;
    final quietEnd = s.prefs.getInt(s.key('engagementQuietEnd')) ?? 8;
    DateTime allowed(DateTime date) =>
        quiet ? afterQuietHours(date, quietStart, quietEnd) : date;
    final limit = (s.prefs.getInt(s.key('engagementDailyLimit')) ?? 3).clamp(
      1,
      4,
    );
    final ledgerRaw = s.prefs.getString(s.key('engagementLedger'));
    final ledger = ledgerRaw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(ledgerRaw) as Map);
    final pendingRecognition = ledger['pendingRecognition'] as Map?;
    if (pendingRecognition != null) {
      final due = DateTime.tryParse(pendingRecognition['at']?.toString() ?? '');
      if (due != null && due.isAfter(now)) {
        final key = pendingRecognition['key'].toString();
        var valid = true;
        if (key.startsWith('goal:')) {
          final earned = achievements.where((a) => 'goal:${a['id']}' == key);
          final match = earned.isEmpty
              ? <TaskData>[]
              : goals.where((g) => g['id'] == earned.first['goalId']).toList();
          valid =
              match.isNotEmpty &&
              goalProgress(match.first, history, now) >=
                  ((match.first['target'] as num?)?.toInt() ?? 1);
        } else if (key.startsWith('streak:')) {
          valid =
              activeDayStreak(history, now) >=
              (int.tryParse(key.split(':').last) ?? 0);
        } else if (key.startsWith('consistency:')) {
          valid = consistentDays(history, now) >= 5;
        }
        final at = allowed(due);
        if (!valid ||
            dayKey(at) != today ||
            !(s.prefs.getBool(s.key('engagementRecognition')) ?? true)) {
          await NotificationService.cancelNotification(base + 40);
          ledger.remove(key);
          ledger.remove('recognized:$today');
          ledger['count:$today'] =
              (((ledger['count:$today'] as num?)?.toInt() ?? 1) - 1).clamp(
                0,
                4,
              );
          ledger.remove('pendingRecognition');
        } else if (at != due && owner(s)) {
          await NotificationService.scheduleNotification(
            id: base + 40,
            title: 'Look at your progress',
            body: pendingRecognition['body'].toString(),
            scheduledTime: at,
            payload: 'progress',
          );
          ledger['pendingRecognition'] = {
            ...pendingRecognition,
            'at': at.toIso8601String(),
          };
        }
      }
    }
    final routine = Map<String, dynamic>.from(ledger['routine'] as Map? ?? {});
    final taskPlans = Map<String, dynamic>.from(
      ledger['taskPlans'] as Map? ?? {},
    );
    routine.removeWhere(
      (key, value) => DateTime.tryParse(value.toString())?.isAfter(now) ?? true,
    );
    taskPlans.removeWhere(
      (key, value) => DateTime.tryParse(value.toString())?.isAfter(now) ?? true,
    );
    var id = base;
    var capacity =
        (50 -
                (await NotificationService.notificationsPlugin
                        .pendingNotificationRequests())
                    .length)
            .clamp(0, 50);

    final used = <String, int>{};
    int usedOn(String day) =>
        used[day] ??
        (((ledger['count:$day'] as num?)?.toInt() ?? 0) +
            routine.keys.where((key) => key.startsWith('$day|')).length);
    // At most one recognition message per day, before routine motivation.
    String? recognitionKey;
    String? recognitionBody;
    if (s.prefs.getBool(s.key('engagementRecognition')) ?? true) {
      for (final a in achievements.reversed) {
        final goal = goals.where((g) => g['id'] == a['goalId']);
        if (goal.isEmpty || a['id'] != goalPeriodKey(goal.first, now)) continue;
        final key = 'goal:${a['id']}';
        if (ledger[key] != true) {
          recognitionKey = key;
          recognitionBody =
              'You reached “${a['title']}”! ${a['target']} linked tasks completed. Take a moment to appreciate your effort.';
          break;
        }
      }
      final streak = activeDayStreak(history, now);
      final lastActive = (history[today] ?? []).any(isTaskComplete)
          ? dayOnly(now)
          : calendarDay(now, -1);
      final anchor = dayKey(calendarDay(lastActive, -streak + 1));
      final milestones = [3, 5, 7, 14, 30, 60, 100];
      final reached = milestones.where((n) => n <= streak).toList();
      if (recognitionKey == null && reached.isNotEmpty) {
        final key = 'streak:$anchor:${reached.last}';
        if (ledger[key] != true) {
          recognitionKey = key;
          recognitionBody =
              '$streak days with completed tasks. You have been showing up consistently—keep building on that effort!';
        }
      }
      final days = consistentDays(history, now);
      final key = 'consistency:${dayKey(sundayOf(now))}';
      if (recognitionKey == null && days >= 5 && ledger[key] != true) {
        recognitionKey = key;
        recognitionBody =
            'You completed tasks on $days of the last 7 days. That effort adds up!';
      }
    }
    if (capacity > 0 &&
        recognitionKey != null &&
        ledger['recognized:$today'] != true &&
        usedOn(today) < limit) {
      final at = allowed(now.add(const Duration(seconds: 10)));
      if (dayKey(at) == today && owner(s)) {
        await NotificationService.scheduleNotification(
          id: base + 40,
          title: 'Look at your progress',
          body: recognitionBody!,
          scheduledTime: at,
          payload: 'progress',
        );
        ledger['pendingRecognition'] = {
          'key': recognitionKey,
          'body': recognitionBody,
          'at': at.toIso8601String(),
        };
        ledger[recognitionKey] = true;
        ledger['recognized:$today'] = true;
        ledger['count:$today'] =
            ((ledger['count:$today'] as num?)?.toInt() ?? 0) + 1;
        capacity--;
        used[today] = usedOn(today);
      }
    }
    // Bounded one-shot horizon leaves room for scheduled task and timer alerts.
    for (var offset = 0; offset < 7; offset++) {
      final date = calendarDay(now, offset);
      for (final kind in ['Morning', 'Goals', 'Midday', 'Evening']) {
        if (s.prefs.getBool(s.key('engagement$kind')) != true) continue;
        if (kind == 'Goals' &&
            date.weekday != DateTime.saturday &&
            date.day != DateTime(date.year, date.month + 1, 0).day &&
            !goals.any((g) => g['targetDate'] == dayKey(date))) {
          continue;
        }
        if (kind == 'Goals' && goals.isEmpty) continue;
        final hour =
            s.prefs.getInt(s.key('engagement${kind}Hour')) ??
            (kind == 'Morning'
                ? 9
                : kind == 'Midday'
                ? 14
                : 20);
        final minute = s.prefs.getInt(s.key('engagement${kind}Minute')) ?? 0;
        final requested = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );
        // Do not send a late morning message when opening the app at night.
        if (!requested.isAfter(now)) continue;
        final at = allowed(requested);
        if (dayKey(at) != dayKey(date)) continue;
        final key = dayKey(at);
        if (capacity <= 0 || usedOn(key) >= limit) continue;
        String body;
        if (kind == 'Morning') {
          final quote = s.prefs.getBool(s.key('engagementQuote')) ?? true;
          body =
              'A fresh day, a fresh start. Choose one thing that matters.${quote ? ' ${quoteForDay(date)}' : ''}';
        } else if (kind == 'Midday') {
          body =
              'There is still time to make today count. Take one small step, then another.';
        } else if (kind == 'Goals') {
          body =
              'How are your weekly, monthly and long-term goals going? Review your linked tasks and choose your next step.';
        } else {
          body = offset == 0
              ? '${(history[today] ?? []).where(isTaskComplete).length} tasks completed today. Give yourself credit for your effort and take a moment to reflect.'
              : 'Take a moment to review your day in TrakOn. Small steps still count.';
        }
        if (!owner(s)) return;
        await NotificationService.scheduleNotification(
          id: id++,
          title: kind == 'Morning'
              ? 'It’s a new day'
              : kind == 'Midday'
              ? 'Keep your momentum'
              : kind == 'Goals'
              ? 'Your goal check-in'
              : 'Your evening reflection',
          body: body,
          scheduledTime: at,
          payload: 'encouragement',
        );
        used[key] = usedOn(key) + 1;
        capacity--;
        routine['$key|$kind'] = at.toIso8601String();
      }
    }
    // Up to five task-specific check-ins for today's saved incomplete tasks.
    if (s.prefs.getBool(s.key('engagementTaskCheckIns')) == true &&
        await NotificationPreferences.taskRemindersEnabled()) {
      final tasks = (history[today] ?? [])
          .where((t) => !isTaskComplete(t))
          .take(5);
      for (final task in tasks) {
        final hour = s.prefs.getInt(s.key('engagementTaskHour')) ?? 18;
        final minute = s.prefs.getInt(s.key('engagementTaskMinute')) ?? 0;
        final at = allowed(
          DateTime(now.year, now.month, now.day, hour, minute),
        );
        if (!at.isAfter(now) || dayKey(at) != today) continue;
        final key = 'task:$today:${taskIdentity(task)}';
        if (capacity <= 0 || taskPlans.containsKey(key)) continue;
        if (!owner(s)) return;
        await NotificationService.scheduleNotification(
          id: id++,
          title: task['status'] == 'In Progress'
              ? 'How is it going?'
              : 'A quick task check-in',
          body: taskCheckInMessage(task),
          scheduledTime: at,
          payload: 'task:${taskIdentity(task)}',
        );
        taskPlans[key] = at.toIso8601String();
        capacity--;
      }
    }
    // Retain celebration keys; routine counts older than a month are expendable.
    ledger.removeWhere((key, value) {
      if (!key.startsWith('count:') && !key.startsWith('recognized:')) {
        return false;
      }
      try {
        return parseDay(
          key.substring(key.indexOf(':') + 1),
        ).isBefore(calendarDay(now, -30));
      } catch (_) {
        return false;
      }
    });
    routine.removeWhere(
      (key, value) =>
          DateTime.parse(value.toString()).isBefore(calendarDay(now, -30)),
    );
    taskPlans.removeWhere(
      (key, value) =>
          DateTime.parse(value.toString()).isBefore(calendarDay(now, -30)),
    );
    ledger['routine'] = routine;
    ledger['taskPlans'] = taskPlans;
    if (!await s.prefs.setString(
      s.key('engagementLedger'),
      jsonEncode(ledger),
    )) {
      throw StateError('Could not save notification history');
    }
  }
}
