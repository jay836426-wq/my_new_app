import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS 26 uses a one-shot system alarm at the session's absolute deadline.
/// Other platforms retain the existing local-notification scheduler.
class FocusAlarmBridge {
  static const _channel = MethodChannel('com.gettrakon.trakon/focus_alarm');
  static String backend = 'notification';
  static String? warning;
  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static Future<void> requestAuthorization() async {
    if (!_ios) return;
    try {
      await _channel.invokeMethod<bool>('requestAuthorization');
    } on MissingPluginException {
      warning = 'Alarm support requires the updated iPhone build.';
    } on PlatformException {
      warning =
          'Alarm access is unavailable. Notification settings still apply.';
    }
  }

  static Future<bool> schedule(
    DateTime deadline,
    String title,
    String body,
  ) async {
    if (!_ios) return false;
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('schedule', {
            'deadline': deadline.millisecondsSinceEpoch / 1000,
            'title': title,
            'body': body,
            'mode': title.startsWith('Break') ? 'Break' : 'Focus',
          });
      backend = result?['backend']?.toString() ?? 'notification';
      warning = result?['warning']?.toString();
      return backend == 'alarm';
    } on MissingPluginException {
      backend = 'notification';
      warning = 'Alarm support requires the updated iPhone build.';
      return false;
    } on PlatformException {
      // Native scheduling already falls back when AlarmKit is unavailable.
      // A bridge error may mean an old alarm could not be cancelled: surface it.
      rethrow;
    }
  }

  static Future<void> cancel() async {
    if (!_ios) return;
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      /* Older binary: nothing native to cancel. */
    } on PlatformException {
      rethrow;
    }
  }

  static Future<void> stopSound() async {
    if (!_ios) return;
    try {
      await _channel.invokeMethod<void>('stopSound');
    } on MissingPluginException {
      /* No custom player in older builds. */
    } on PlatformException {
      /* UI remains usable if audio is unavailable. */
    }
  }

  static String soundFor(String title) =>
      title.startsWith('Break') ? 'trakon_break.wav' : 'trakon_focus.wav';
}
