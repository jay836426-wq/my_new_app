import 'package:shared_preferences/shared_preferences.dart';

// Stores and loads the user's notification settings.
class NotificationPreferences {
  // SharedPreferences keys.
  static const String notificationsEnabledKey = 'notificationsEnabled';

  static const String taskRemindersEnabledKey = 'taskRemindersEnabled';

  static const String highPriorityRemindersEnabledKey =
      'highPriorityRemindersEnabled';

  static const String dailySummaryEnabledKey = 'dailySummaryEnabled';

  static const String endOfDayEnabledKey = 'endOfDayEnabled';

  static const String dailyMotivationEnabledKey = 'dailyMotivationEnabled';

  static const String carryOverNotificationsEnabledKey =
      'carryOverNotificationsEnabled';

  static const String streakNotificationsEnabledKey =
      'streakNotificationsEnabled';

  // Time settings.
  static const String dailySummaryHourKey = 'dailySummaryHour';

  static const String dailySummaryMinuteKey = 'dailySummaryMinute';

  static const String endOfDayHourKey = 'endOfDayHour';

  static const String endOfDayMinuteKey = 'endOfDayMinute';

  static const String motivationHourKey = 'motivationHour';

  static const String motivationMinuteKey = 'motivationMinute';

  // Returns whether all notifications are enabled.
  static Future<bool> notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(notificationsEnabledKey) ?? true;
  }

  // Returns whether normal task reminders are enabled.
  static Future<bool> taskRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(taskRemindersEnabledKey) ?? true;
  }

  // Returns whether repeated high-priority reminders are enabled.
  static Future<bool> highPriorityRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(highPriorityRemindersEnabledKey) ?? true;
  }

  // Returns whether daily summary notifications are enabled.
  static Future<bool> dailySummaryEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(dailySummaryEnabledKey) ?? true;
  }

  // Returns whether end-of-day notifications are enabled.
  static Future<bool> endOfDayEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(endOfDayEnabledKey) ?? true;
  }

  // Returns whether motivational notifications are enabled.
  static Future<bool> dailyMotivationEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(dailyMotivationEnabledKey) ?? true;
  }

  // Returns whether carry-over notifications are enabled.
  static Future<bool> carryOverNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(carryOverNotificationsEnabledKey) ?? true;
  }

  // Returns whether streak notifications are enabled.
  static Future<bool> streakNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(streakNotificationsEnabledKey) ?? true;
  }

  // Default daily summary time: 6:00 PM.
  static Future<int> dailySummaryHour() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(dailySummaryHourKey) ?? 18;
  }

  static Future<int> dailySummaryMinute() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(dailySummaryMinuteKey) ?? 0;
  }

  // Default end-of-day time: 9:00 PM.
  static Future<int> endOfDayHour() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(endOfDayHourKey) ?? 21;
  }

  static Future<int> endOfDayMinute() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(endOfDayMinuteKey) ?? 0;
  }

  // Default motivation time: 9:00 AM.
  static Future<int> motivationHour() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(motivationHourKey) ?? 9;
  }

  static Future<int> motivationMinute() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(motivationMinuteKey) ?? 0;
  }

  // Saves one Boolean notification setting.
  static Future<void> setBool({
    required String key,
    required bool value,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(key, value);
  }

  // Saves the daily summary time.
  static Future<void> setDailySummaryTime({
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(dailySummaryHourKey, hour);
    await prefs.setInt(dailySummaryMinuteKey, minute);
  }

  // Saves the end-of-day notification time.
  static Future<void> setEndOfDayTime({
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(endOfDayHourKey, hour);
    await prefs.setInt(endOfDayMinuteKey, minute);
  }

  // Saves the motivation notification time.
  static Future<void> setMotivationTime({
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(motivationHourKey, hour);
    await prefs.setInt(motivationMinuteKey, minute);
  }
}
