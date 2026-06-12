import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Handles all local notifications in app
class NotificationService {

  // Create notification plugin instance
  static final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  // Intialize notifications
  static Future init() async {

    // Android settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
    );

    // Combine Android and iOS settings
    const InitializationSettings settings =
        InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );

    // Start notifications
    await notificationsPlugin.initialize(settings: settings,);
  }



  // Show a notification
  static Future showNotification({
    required String title,
    required String body,
  }) async{
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'task_channel', 
          'Task Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
    
    const NotificationDetails details = 
        NotificationDetails(
          android: androidDetails,
    );

    await notificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}