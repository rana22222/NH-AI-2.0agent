import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotifyService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    try {
      const InitializationSettings settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(settings);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {}
  }

  static Future<void> show(int id, String title, String body) async {
    try {
      await init();
      const NotificationDetails details = NotificationDetails(
        android: AndroidNotificationDetails(
          'nhai_tasks',
          'কাজের বিজ্ঞপ্তি',
          channelDescription: 'কাজ শেষ হলে জানানো হবে',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _plugin.show(id, title, body, details);
    } catch (_) {}
  }
}
