import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Handles all local notifications throughout the TrakOn app.
class NotificationService {
  // Creates one notification plugin instance for the entire app.
  static final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Prevents the service from being initialized more than once.
  static bool _isInitialized = false;

  // Reserved IDs for notifications that are not connected to one task.
  static const int dailySummaryNotificationId = 9000001;
  static const int endOfDayNotificationId = 9000002;
  static const int motivationalNotificationId = 9000003;
  static const int carryOverNotificationId = 9000004;
  static const int streakNotificationId = 9000005;
  static const int dayCompletedNotificationId = 9000006;

  // Initializes notification settings.
  static Future<void> init() async {
    if (_isInitialized) return;

    // Loads the time zone database used for scheduled notifications.
    tz.initializeTimeZones();

    // Sets scheduled notifications to Eastern Time.
    tz.setLocalLocation(
      tz.getLocation('America/New_York'),
    );

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await notificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (
        NotificationResponse response,
      ) {
        debugPrint(
          'Notification selected. Payload: ${response.payload}',
        );
      },
    );

    _isInitialized = true;
  }

  // Requests notification permission on iPhone.
  static Future<bool> requestPermissions() async {
    final bool? permissionGranted = await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return permissionGranted ?? false;
  }

  // Creates the standard notification appearance.
  static NotificationDetails _notificationDetails({
    String channelId = 'task_channel',
    String channelName = 'Task Notifications',
    String channelDescription =
        'Notifications for TrakOn tasks and reminders',
  }) {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  // Converts a task ID into a safe group of notification IDs.
  //
  // Each task receives 100 possible notification IDs:
  // base + 0 = original reminder
  // base + 1 through 10 = high-priority repeats
  // base + 20 = missed-task reminder
  static int _taskBaseNotificationId(int taskId) {
    final int safeTaskId = taskId.abs() % 80000;
    return safeTaskId * 100;
  }

  // Shows a notification immediately.
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _notificationDetails(),
      payload: payload,
    );
  }

  // Schedules one notification for a future time.
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) {
      debugPrint(
        'Notification $id was not scheduled because its time passed.',
      );
      return;
    }

    await notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      ),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    debugPrint(
      'Scheduled notification $id for $scheduledTime.',
    );
  }

  // ---------------------------------------------------------------------------
  // 1. STANDARD TASK REMINDER
  // 2. HIGH-PRIORITY REPEATED REMINDERS
  // 3. MISSED-TASK REMINDER
  // ---------------------------------------------------------------------------

  // Schedules every notification connected to one task.
  static Future<void> scheduleTaskNotifications({
    required int taskId,
    required String taskTitle,
    required DateTime reminderTime,
    required bool isHighPriority,
    bool scheduleMissedTaskReminder = true,
    Duration highPriorityRepeatInterval = const Duration(minutes: 15),
    int highPriorityRepeatCount = 3,
    Duration missedTaskDelay = const Duration(minutes: 30),
  }) async {
    // Removes old reminders before scheduling updated ones.
    await cancelTaskNotifications(taskId);

    final int baseId = _taskBaseNotificationId(taskId);

    // Schedules the normal reminder selected by the user.
    await scheduleNotification(
      id: baseId,
      title: isHighPriority
          ? 'High-Priority Task'
          : 'Task Reminder',
      body: taskTitle,
      scheduledTime: reminderTime,
      payload: 'task:$taskId',
    );

    // High-priority tasks receive additional reminders.
    if (isHighPriority) {
      final int safeRepeatCount =
          highPriorityRepeatCount.clamp(0, 10);

      for (int repeat = 1; repeat <= safeRepeatCount; repeat++) {
        final DateTime repeatTime = reminderTime.add(
          Duration(
            minutes:
                highPriorityRepeatInterval.inMinutes * repeat,
          ),
        );

        await scheduleNotification(
          id: baseId + repeat,
          title: 'High-Priority Task Still Waiting',
          body:
              '$taskTitle is still waiting. Stay focused and finish it.',
          scheduledTime: repeatTime,
          payload: 'task:$taskId',
        );
      }
    }

    // This notification remains scheduled unless the task is completed,
    // edited, or deleted before the missed-task time.
    if (scheduleMissedTaskReminder) {
      final DateTime missedTime = reminderTime.add(
        missedTaskDelay,
      );

      await scheduleNotification(
        id: baseId + 20,
        title: 'Did You Miss This Task?',
        body:
            '$taskTitle has not been marked complete. You can still get back on track.',
        scheduledTime: missedTime,
        payload: 'task:$taskId',
      );
    }
  }

  // Cancels all notifications connected to one task.
  //
  // Call this when the task is completed, deleted, or edited.
  static Future<void> cancelTaskNotifications(int taskId) async {
    final int baseId = _taskBaseNotificationId(taskId);

    // Cancels the normal reminder and up to 10 repeated reminders.
    for (int offset = 0; offset <= 10; offset++) {
      await notificationsPlugin.cancel(
        id: baseId + offset,
      );
    }

    // Cancels the missed-task reminder.
    await notificationsPlugin.cancel(
      id: baseId + 20,
    );

    debugPrint(
      'Cancelled notifications for task $taskId.',
    );
  }

  // ---------------------------------------------------------------------------
  // 4. DAILY TASK SUMMARY
  // ---------------------------------------------------------------------------

  // Schedules a summary showing how many tasks remain that day.
  //
  // The app should call this again whenever the task count changes so the
  // notification body stays accurate.
  static Future<void> scheduleDailyTaskSummary({
    required DateTime scheduledTime,
    required int remainingTaskCount,
  }) async {
    await notificationsPlugin.cancel(
      id: dailySummaryNotificationId,
    );

    if (remainingTaskCount <= 0) {
      debugPrint(
        'Daily summary was not scheduled because no tasks remain.',
      );
      return;
    }

    final String taskWord =
        remainingTaskCount == 1 ? 'task' : 'tasks';

    await scheduleNotification(
      id: dailySummaryNotificationId,
      title: 'Today’s Task Summary',
      body:
          'You have $remainingTaskCount $taskWord remaining today. Keep going!',
      scheduledTime: scheduledTime,
      payload: 'daily_summary',
    );
  }

  // ---------------------------------------------------------------------------
  // 5. END-OF-DAY NOTIFICATION
  // ---------------------------------------------------------------------------

  // Schedules an evening reminder about unfinished tasks.
  static Future<void> scheduleEndOfDayNotification({
    required DateTime scheduledTime,
    required int remainingTaskCount,
  }) async {
    await notificationsPlugin.cancel(
      id: endOfDayNotificationId,
    );

    if (remainingTaskCount <= 0) {
      debugPrint(
        'End-of-day notification was not scheduled because all tasks are complete.',
      );
      return;
    }

    final String taskWord =
        remainingTaskCount == 1 ? 'task' : 'tasks';

    await scheduleNotification(
      id: endOfDayNotificationId,
      title: 'Finish the Day Strong',
      body:
          'You still have $remainingTaskCount $taskWord left. Finish them now or carry them into tomorrow.',
      scheduledTime: scheduledTime,
      payload: 'end_of_day',
    );
  }

  // ---------------------------------------------------------------------------
  // 6. CARRY-OVER NOTIFICATION
  // ---------------------------------------------------------------------------

  // Immediately reports that unfinished tasks were moved to today.
  static Future<void> showCarryOverNotification({
    required int carriedTaskCount,
  }) async {
    if (carriedTaskCount <= 0) return;

    final String taskWord =
        carriedTaskCount == 1 ? 'task was' : 'tasks were';

    await showNotification(
      id: carryOverNotificationId,
      title: 'Tasks Carried Over',
      body:
          '$carriedTaskCount unfinished $taskWord moved to today.',
      payload: 'carry_over',
    );
  }

  // ---------------------------------------------------------------------------
  // 7A. DAILY MOTIVATIONAL NOTIFICATION
  // ---------------------------------------------------------------------------

  // Schedules a motivational message at the same time every day.
  static Future<void> scheduleDailyMotivationalNotification({
    required int hour,
    required int minute,
    String message =
        'Small progress is still progress. Stay focused and keep moving.',
  }) async {
    await notificationsPlugin.cancel(
      id: motivationalNotificationId,
    );

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime nextNotification = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If today's time passed, begin tomorrow.
    if (nextNotification.isBefore(now)) {
      nextNotification = nextNotification.add(
        const Duration(days: 1),
      );
    }

    await notificationsPlugin.zonedSchedule(
      id: motivationalNotificationId,
      title: 'Your TrakOn Motivation',
      body: message,
      scheduledDate: nextNotification,
      notificationDetails: _notificationDetails(
        channelId: 'motivation_channel',
        channelName: 'Motivational Notifications',
        channelDescription:
            'Daily motivation and productivity messages',
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'motivation',
    );

    debugPrint(
      'Daily motivation scheduled for $hour:${minute.toString().padLeft(2, '0')}.',
    );
  }

  // Cancels the recurring motivational notification.
  static Future<void> cancelDailyMotivationalNotification() async {
    await notificationsPlugin.cancel(
      id: motivationalNotificationId,
    );
  }

  // ---------------------------------------------------------------------------
  // 7B. STREAK AND COMPLETION NOTIFICATIONS
  // ---------------------------------------------------------------------------

  // Shows a congratulatory notification when the streak increases.
  static Future<void> showStreakNotification({
    required int streakCount,
  }) async {
    if (streakCount <= 0) return;

    final String dayWord = streakCount == 1 ? 'day' : 'days';

    await showNotification(
      id: streakNotificationId,
      title: 'Streak Continued!',
      body:
          'You are now on a $streakCount-$dayWord streak. Keep the momentum going!',
      payload: 'streak',
    );
  }

  // Shows a notification when every task for the day is complete.
  static Future<void> showDayCompletedNotification() async {
    // An end-of-day reminder is no longer needed.
    await notificationsPlugin.cancel(
      id: dailySummaryNotificationId,
    );

    await notificationsPlugin.cancel(
      id: endOfDayNotificationId,
    );

    await showNotification(
      id: dayCompletedNotificationId,
      title: 'Day Complete!',
      body:
          'You completed all of today’s tasks. Great work staying on track!',
      payload: 'day_complete',
    );
  }

  // ---------------------------------------------------------------------------
  // TESTING
  // ---------------------------------------------------------------------------

  // Schedules examples of every notification type a few seconds apart.
  //
  // Use this temporarily while testing on your iPhone.
  static Future<void> testAllSmartNotifications() async {
    final DateTime now = DateTime.now();

    await scheduleNotification(
      id: 9100001,
      title: 'Task Reminder Test',
      body: 'This is a standard task reminder.',
      scheduledTime: now.add(
        const Duration(seconds: 10),
      ),
    );

    await scheduleNotification(
      id: 9100002,
      title: 'High-Priority Test',
      body: 'This task needs your attention.',
      scheduledTime: now.add(
        const Duration(seconds: 20),
      ),
    );

    await scheduleNotification(
      id: 9100003,
      title: 'Missed Task Test',
      body: 'This task has not been marked complete.',
      scheduledTime: now.add(
        const Duration(seconds: 30),
      ),
    );

    await scheduleNotification(
      id: 9100004,
      title: 'Daily Summary Test',
      body: 'You have 3 tasks remaining today.',
      scheduledTime: now.add(
        const Duration(seconds: 40),
      ),
    );

    await scheduleNotification(
      id: 9100005,
      title: 'End-of-Day Test',
      body: 'Finish strong or prepare your remaining tasks for tomorrow.',
      scheduledTime: now.add(
        const Duration(seconds: 50),
      ),
    );

    await scheduleNotification(
      id: 9100006,
      title: 'Carry-Over Test',
      body: '2 unfinished tasks were moved to today.',
      scheduledTime: now.add(
        const Duration(seconds: 60),
      ),
    );

    await scheduleNotification(
      id: 9100007,
      title: 'Motivation Test',
      body: 'Stay focused. Every completed task moves you forward.',
      scheduledTime: now.add(
        const Duration(seconds: 70),
      ),
    );
  }

  // Returns all notifications that are currently waiting to be delivered.
  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return notificationsPlugin.pendingNotificationRequests();
  }

  // Cancels one specific notification.
  static Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id: id);
  }

  // Cancels every pending notification.
  static Future<void> cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
  }
}