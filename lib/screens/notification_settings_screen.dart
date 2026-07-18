import 'package:flutter/material.dart';
import 'notification_preferences.dart';

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
    notificationsEnabled =
        await NotificationPreferences.notificationsEnabled();

    taskRemindersEnabled =
        await NotificationPreferences.taskRemindersEnabled();

    highPriorityRemindersEnabled =
        await NotificationPreferences.highPriorityRemindersEnabled();

    dailySummaryEnabled =
        await NotificationPreferences.dailySummaryEnabled();

    endOfDayEnabled =
        await NotificationPreferences.endOfDayEnabled();

    dailyMotivationEnabled =
        await NotificationPreferences.dailyMotivationEnabled();

    carryOverNotificationsEnabled =
        await NotificationPreferences.carryOverNotificationsEnabled();

    streakNotificationsEnabled =
        await NotificationPreferences.streakNotificationsEnabled();

    final summaryHour =
        await NotificationPreferences.dailySummaryHour();

    final summaryMinute =
        await NotificationPreferences.dailySummaryMinute();

    final endHour =
        await NotificationPreferences.endOfDayHour();

    final endMinute =
        await NotificationPreferences.endOfDayMinute();

    final motivationHour =
        await NotificationPreferences.motivationHour();

    final motivationMinute =
        await NotificationPreferences.motivationMinute();

    if (!mounted) return;

    setState(() {
      dailySummaryTime = TimeOfDay(
        hour: summaryHour,
        minute: summaryMinute,
      );

      endOfDayTime = TimeOfDay(
        hour: endHour,
        minute: endMinute,
      );

      motivationTime = TimeOfDay(
        hour: motivationHour,
        minute: motivationMinute,
      );

      isLoading = false;
    });
  }

  Future<void> updateSetting({
    required String key,
    required bool value,
  }) async {
    await NotificationPreferences.setBool(
      key: key,
      value: value,
    );
  }

  Future<void> chooseDailySummaryTime() async {
    final selectedTime = await showTimePicker(
      context: context,
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
  }

  Future<void> chooseEndOfDayTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: endOfDayTime,
    );

    if (selectedTime == null) return;

    await NotificationPreferences.setEndOfDayTime(
      hour: selectedTime.hour,
      minute: selectedTime.minute,
    );

    if (!mounted) return;

    setState(() {
      endOfDayTime = selectedTime;
    });
  }

  Future<void> chooseMotivationTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: motivationTime,
    );

    if (selectedTime == null) return;

    await NotificationPreferences.setMotivationTime(
      hour: selectedTime.hour,
      minute: selectedTime.minute,
    );

    if (!mounted) return;

    setState(() {
      motivationTime = selectedTime;
    });
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
      activeColor: Colors.greenAccent,
      secondary: icon == null
          ? null
          : Icon(
              icon,
              color: value ? Colors.greenAccent : Colors.white54,
            ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.white60,
        ),
      ),
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
      leading: const Icon(
        Icons.schedule,
        color: Colors.white70,
      ),
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
              child: CircularProgressIndicator(
                color: Colors.greenAccent,
              ),
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
                    activeColor: Colors.greenAccent,
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
                        key: NotificationPreferences
                            .notificationsEnabledKey,
                        value: value,
                      );
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
                      key: NotificationPreferences
                          .taskRemindersEnabledKey,
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
                      key: NotificationPreferences
                          .dailyMotivationEnabledKey,
                      value: value,
                    );
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
                      key: NotificationPreferences
                          .dailySummaryEnabledKey,
                      value: value,
                    );
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
                  subtitle:
                      'Receive a final reminder for unfinished tasks.',
                  value: endOfDayEnabled,
                  icon: Icons.nightlight_round,
                  onChanged: (value) async {
                    setState(() {
                      endOfDayEnabled = value;
                    });

                    await updateSetting(
                      key: NotificationPreferences
                          .endOfDayEnabledKey,
                      value: value,
                    );
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
                  subtitle:
                      'Celebrate streaks and completed days.',
                  value: streakNotificationsEnabled,
                  icon: Icons.local_fire_department,
                  onChanged: (value) async {
                    setState(() {
                      streakNotificationsEnabled = value;
                    });

                    await updateSetting(
                      key: NotificationPreferences
                          .streakNotificationsEnabledKey,
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