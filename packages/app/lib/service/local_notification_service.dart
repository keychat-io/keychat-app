import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class LocalNotificationService {
  factory LocalNotificationService() => _instance;

  LocalNotificationService._internal();
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize the notification service
  Future<void> initialize() async {
    // Android initialization settings
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );

    // // macOS initialization settings
    // const initializationSettingsMacOS = DarwinInitializationSettings();

    // Linux initialization settings
    const initializationSettingsLinux = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    // Combined initialization settings
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      // macOS: initializationSettingsMacOS,
      linux: initializationSettingsLinux,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // // Request permissions for iOS/macOS
    // if (defaultTargetPlatform == TargetPlatform.iOS ||
    //     defaultTargetPlatform == TargetPlatform.macOS) {
    //   await _requestPermissions();
    // }

    // Create notification channel for Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _createNotificationChannel();
    }
  }

  /// Request notification permissions for iOS/macOS
  Future<void> _requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'keychat_channel', // id
      'Keychat Notifications', // name
      description: 'This channel is used for Keychat notifications',
      importance: Importance.high,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Callback when notification is received while app is in foreground (iOS only)
  void onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) {
    // Handle notification received while app is in foreground
    if (kDebugMode) {
      print('Notification received: $title - $body');
    }
  }

  /// Callback when notification is tapped
  void onDidReceiveNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      if (kDebugMode) {
        print('Notification tapped with payload: $payload');
      }
      // Handle notification tap, e.g., navigate to specific screen
    }
  }

  /// Show a simple notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'keychat_channel',
      'Keychat Notifications',
      channelDescription: 'This channel is used for Keychat notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const linuxDetails = LinuxNotificationDetails();

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
      macOS: macOSDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // /// Schedule a notification
  // Future<void> scheduleNotification({
  //   required int id,
  //   required String title,
  //   required String body,
  //   required DateTime scheduledDate,
  //   String? payload,
  // }) async {
  //   const androidDetails = AndroidNotificationDetails(
  //     'keychat_channel',
  //     'Keychat Notifications',
  //     channelDescription: 'This channel is used for Keychat notifications',
  //     importance: Importance.high,
  //     priority: Priority.high,
  //   );

  //   const iOSDetails = DarwinNotificationDetails();
  //   const macOSDetails = DarwinNotificationDetails();
  //   const linuxDetails = LinuxNotificationDetails();

  //   const platformDetails = NotificationDetails(
  //     android: androidDetails,
  //     iOS: iOSDetails,
  //     macOS: macOSDetails,
  //     linux: linuxDetails,
  //   );

  //   final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
  //   await _notificationsPlugin.zonedSchedule(
  //     id,
  //     title,
  //     body,
  //     tzScheduledDate,
  //     platformDetails,
  //     androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  //     payload: payload,
  //   );
  // }

  /// Cancel a notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _notificationsPlugin.pendingNotificationRequests();
  }

  /// Get active notifications (Android only)
  Future<List<ActiveNotification>> getActiveNotifications() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      return androidImplementation.getActiveNotifications();
    }
    return [];
  }
}
