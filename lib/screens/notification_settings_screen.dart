import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_preferences.dart';
import 'notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool notificationsEnabled = true;
  bool taskRemindersEnabled = true;
  bool highPriorityRemindersEnabled = true;
  bool dailySummaryEnabled = true;
  bool endOfDayEnabled = true;
  bool dailyMotivationEnabled = true;
  bool carryOverNotificationsEnabled = true;
  bool streakNotificationsEnabled = true;

  TimeOfDay dailySummaryTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay endOfDayTime = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay motivationTime = const TimeOfDay(hour: 9, minute: 0);

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadNotificationSettings();
  }

  Future<void> loadNotificationSettings() async {
    notificationsEnabled = await NotificationPreferences.notificationsEnabled();

    taskRemindersEnabled = await NotificationPreferences.taskRemindersEnabled();

    highPriorityRemindersEnabled =
        await NotificationPreferences.highPriorityRemindersEnabled();

    dailySummaryEnabled = await NotificationPreferences.dailySummaryEnabled();

    endOfDayEnabled = await NotificationPreferences.endOfDayEnabled();

    dailyMotivationEnabled =
        await NotificationPreferences.dailyMotivationEnabled();

    carryOverNotificationsEnabled =
        await NotificationPreferences.carryOverNotificationsEnabled();

    streakNotificationsEnabled =
        await NotificationPreferences.streakNotificationsEnabled();

    final summaryHour = await NotificationPreferences.dailySummaryHour();

    final summaryMinute = await NotificationPreferences.dailySummaryMinute();

    final endHour = await NotificationPreferences.endOfDayHour();

    final endMinute = await NotificationPreferences.endOfDayMinute();

    final motivationHour = await NotificationPreferences.motivationHour();

    final motivationMinute = await NotificationPreferences.motivationMinute();

    if (!mounted) return;

    setState(() {
      dailySummaryTime = TimeOfDay(hour: summaryHour, minute: summaryMinute);

      endOfDayTime = TimeOfDay(hour: endHour, minute: endMinute);

      motivationTime = TimeOfDay(
        hour: motivationHour,
        minute: motivationMinute,
      );

      isLoading = false;
    });
  }

  Future<void> updateSetting({required String key, required bool value}) async {
    await NotificationPreferences.setBool(key: key, value: value);
  }

  Future<int> getRemainingTaskCount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTasks = prefs.getString('tasks');

    if (savedTasks == null) {
      return 0;
    }

    try {
      final List<dynamic> decodedTasks = jsonDecode(savedTasks);

      return decodedTasks.where((task) {
        return task is Map && task['completed'] != true;
      }).length;
    } catch (error) {
      debugPrint('Could not read tasks for notifications: $error');
      return 0;
    }
  }

  DateTime getNextNotificationTime(TimeOfDay time) {
    final now = DateTime.now();

    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (!scheduledTime.isAfter(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    return scheduledTime;
  }

  Future<void> scheduleDailySummary() async {
    final remainingTaskCount = await getRemainingTaskCount();

    await NotificationService.scheduleDailyTaskSummary(
      scheduledTime: getNextNotificationTime(dailySummaryTime),
      remainingTaskCount: remainingTaskCount,
    );
  }

  Future<void> scheduleEndOfDayReminder() async {
    final remainingTaskCount = await getRemainingTaskCount();

    await NotificationService.scheduleEndOfDayNotification(
      scheduledTime: getNextNotificationTime(endOfDayTime),
      remainingTaskCount: remainingTaskCount,
    );
  }

  Future<void> scheduleEnabledDailyNotifications() async {
    if (!notificationsEnabled) {
      return;
    }

    if (dailyMotivationEnabled) {
      await NotificationService.scheduleDailyMotivationalNotification(
        hour: motivationTime.hour,
        minute: motivationTime.minute,
      );
    }

    if (dailySummaryEnabled) {
      await scheduleDailySummary();
    }

    if (endOfDayEnabled) {
      await scheduleEndOfDayReminder();
    }
  }

  Future<TimeOfDay?> showAppleTimePicker({
    required TimeOfDay initialTime,
  }) async {
    DateTime selectedDateTime = DateTime(
      2026,
      1,
      1,
      initialTime.hour,
      initialTime.minute,
    );

    final bool? confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (popupContext) {
        return Container(
          height: 330,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(
                  height: 55,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        onPressed: () {
                          Navigator.pop(popupContext, false);
                        },
                        child: const Text('Cancel'),
                      ),
                      const Text(
                        'Select Time',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      CupertinoButton(
                        onPressed: () {
                          Navigator.pop(popupContext, true);
                        },
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: false,
                    initialDateTime: selectedDateTime,
                    onDateTimeChanged: (newDateTime) {
                      selectedDateTime = newDateTime;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) {
      return null;
    }

    return TimeOfDay(
      hour: selectedDateTime.hour,
      minute: selectedDateTime.minute,
    );
  }

  Future<void> chooseDailySummaryTime() async {
    final selectedTime = await showAppleTimePicker(
      initialTime: dailySummaryTime,
    );

    if (selectedTime == null) return;

    await NotificationPreferences.setDailySummaryTime(
      hour: selectedTime.hour,
      minute: selectedTime.minute,
    );

    if (!mounted) return;

    setState(() {
      dailySummaryTime = selectedTime;
    });

    if (notificationsEnabled && dailySummaryEnabled) {
      await scheduleDailySummary();
    }
  }

  Future<void> chooseEndOfDayTime() async {
    final selectedTime = await showAppleTimePicker(initialTime: endOfDayTime);

    if (selectedTime == null) return;

    await NotificationPreferences.setEndOfDayTime(
      hour: selectedTime.hour,
      minute: selectedTime.minute,
    );

    if (!mounted) return;

    setState(() {
      endOfDayTime = selectedTime;
    });

    if (notificationsEnabled && endOfDayEnabled) {
      await scheduleEndOfDayReminder();
    }
  }

  Future<void> chooseMotivationTime() async {
    final selectedTime = await showAppleTimePicker(initialTime: motivationTime);

    if (selectedTime == null) return;

    await NotificationPreferences.setMotivationTime(
      hour: selectedTime.hour,
      minute: selectedTime.minute,
    );

    if (!mounted) return;

    setState(() {
      motivationTime = selectedTime;
    });

    if (notificationsEnabled && dailyMotivationEnabled) {
      await NotificationService.scheduleDailyMotivationalNotification(
        hour: selectedTime.hour,
        minute: selectedTime.minute,
      );
    }
  }

  Widget buildNotificationSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
  }) {
    return SwitchListTile(
      value: value,
      activeThumbColor: Colors.greenAccent,
      secondary: icon == null
          ? null
          : Icon(icon, color: value ? Colors.greenAccent : Colors.white54),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
      onChanged: notificationsEnabled ? onChanged : null,
    );
  }

  Widget buildTimeTile({
    required String title,
    required TimeOfDay time,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return ListTile(
      enabled: notificationsEnabled && enabled,
      leading: const Icon(Icons.schedule, color: Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          color: notificationsEnabled && enabled
              ? Colors.white
              : Colors.white38,
        ),
      ),
      trailing: Text(
        time.format(context),
        style: TextStyle(
          color: notificationsEnabled && enabled
              ? Colors.greenAccent
              : Colors.white38,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: notificationsEnabled && enabled ? onTap : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    value: notificationsEnabled,
                    activeThumbColor: Colors.greenAccent,
                    secondary: const Icon(
                      Icons.notifications_active,
                      color: Colors.greenAccent,
                    ),
                    title: const Text(
                      'All Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Turn all TrakOn notifications on or off.',
                      style: TextStyle(color: Colors.white60),
                    ),
                    onChanged: (value) async {
                      setState(() {
                        notificationsEnabled = value;
                      });

                      await updateSetting(
                        key: NotificationPreferences.notificationsEnabledKey,
                        value: value,
                      );

                      if (!value) {
                        await NotificationService.cancelAllNotifications();
                      } else {
                        await NotificationService.requestPermissions();
                        await scheduleEnabledDailyNotifications();
                      }
                    },
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Task Notifications',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                buildNotificationSwitch(
                  title: 'Task Reminders',
                  subtitle: 'Receive reminders for scheduled tasks.',
                  value: taskRemindersEnabled,
                  icon: Icons.task_alt,
                  onChanged: (value) async {
                    setState(() {
                      taskRemindersEnabled = value;
                    });

                    await updateSetting(
                      key: NotificationPreferences.taskRemindersEnabledKey,
                      value: value,
                    );
                  },
                ),

                buildNotificationSwitch(
                  title: 'High-Priority Reminders',
                  subtitle:
                      'Receive additional reminders for high-priority tasks.',
                  value: highPriorityRemindersEnabled,
                  icon: Icons.priority_high,
                  onChanged: (value) async {
                    setState(() {
                      highPriorityRemindersEnabled = value;
                    });

                    await updateSetting(
                      key: NotificationPreferences
                          .highPriorityRemindersEnabledKey,
                      value: value,
                    );
                  },
                ),

                buildNotificationSwitch(
                  title: 'Carry-Over Notifications',
                  subtitle:
                      'Be notified when unfinished tasks are carried over.',
                  value: carryOverNotificationsEnabled,
                  icon: Icons.redo,
                  onChanged: (value) async {
                    setState(() {
                      carryOverNotificationsEnabled = value;
                    });

                    await updateSetting(
                      key: NotificationPreferences
                          .carryOverNotificationsEnabledKey,
                      value: value,
                    );
                  },
                ),

                const Divider(color: Colors.white24),

                const Text(
                  'Daily Notifications',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                buildNotificationSwitch(
                  title: 'Daily Motivation',
                  subtitle: 'Receive a motivational quote each morning.',
                  value: dailyMotivationEnabled,
                  icon: Icons.lightbulb_outline,
                  onChanged: (value) async {
                    setState(() {
                      dailyMotivationEnabled = value;
                    });

                    await updateSetting(
                      key: NotificationPreferences.dailyMotivationEnabledKey,
                      value: value,
                    );

                    if (value && notificationsEnabled) {
                      await NotificationService.scheduleDailyMotivationalNotification(
                        hour: motivationTime.hour,
                        minute: motivationTime.minute,
                      );
                    } else {
                      await NotificationService.cancelDailyMotivationalNotification();
                    }
                  },
                ),

                buildTimeTile(
                  title: 'Motivation Time',
                  time: motivationTime,
                  enabled: dailyMotivationEnabled,
                  onTap: chooseMotivationTime,
                ),

                buildNotificationSwitch(
                  title: 'Daily Summary',
                  subtitle:
                      'Receive a summary of completed and remaining tasks.',
                  value: dailySummaryEnabled,
                  icon: Icons.summarize,
                  onChanged: (value) async {
                    setState(() {
                      dailySummaryEnabled = value;
                    });

                    await updateSetting(
                      key: NotificationPreferences.dailySummaryEnabledKey,
                      value: value,
                    );

                    if (value && notificationsEnabled) {
                      await scheduleDailySummary();
                    } else {
                      await NotificationService.cancelNotification(
                        NotificationService.dailySummaryNotificationId,
                      );
                    }
                  },
                ),

                buildTimeTile(
                  title: 'Daily Summary Time',
                  time: dailySummaryTime,
                  enabled: dailySummaryEnabled,
                  onTap: chooseDailySummaryTime,
                ),

                buildNotificationSwitch(
                  title: 'End-of-Day Reminder',
                  subtitle: 'Receive a final reminder for unfinished tasks.',
                  value: endOfDayEnabled,
                  icon: Icons.nightlight_round,
                  onChanged: (value) async {
                    setState(() {
                      endOfDayEnabled = value;
                    });

                    await updateSetting(
                      key: NotificationPreferences.endOfDayEnabledKey,
                      value: value,
                    );

                    if (value && notificationsEnabled) {
                      await scheduleEndOfDayReminder();
                    } else {
                      await NotificationService.cancelNotification(
                        NotificationService.endOfDayNotificationId,
                      );
                    }
                  },
                ),

                buildTimeTile(
                  title: 'End-of-Day Time',
                  time: endOfDayTime,
                  enabled: endOfDayEnabled,
                  onTap: chooseEndOfDayTime,
                ),

                buildNotificationSwitch(
                  title: 'Streak Notifications',
                  subtitle: 'Celebrate streaks and completed days.',
                  value: streakNotificationsEnabled,
                  icon: Icons.local_fire_department,
                  onChanged: (value) async {
                    setState(() {
                      streakNotificationsEnabled = value;
                    });

                    await updateSetting(
                      key:
                          NotificationPreferences.streakNotificationsEnabledKey,
                      value: value,
                    );
                  },
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
