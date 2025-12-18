import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:keychat/global.dart';
import 'package:unifiedpush/unifiedpush.dart';

abstract class UPNotificationUtils {
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static bool _notificationInitialized = false;

  static Map<String, String> decodeMessageContentsUri(String message) {
    final uri = Uri.decodeComponent(message).split('&');
    final decoded = <String, String>{};
    for (final i in uri) {
      try {
        decoded[i.split('=')[0]] = i.split('=')[1];
      } on Exception {
        debugPrint("Couldn't decode $i");
      }
    }
    return decoded;
  }

  static Future<bool> basicOnNotification(
    PushMessage message,
    String instance,
  ) async {
    debugPrint('instance $instance');
    if (instance != KeychatGlobal.appName) {
      return false;
    }
    String payload;
    try {
      payload = utf8.decode(message.content);
    } catch (e) {
      // We may have a FormatException while doing utf8.decode, if it was encrypted
      // but we couldn't decrypt it.
      debugPrint(
        "Couldn't decrypt content (decrypted=${message.decrypted}): $e",
      );
      payload = "Couldn't decrypt";
    }

    var title = 'UnifiedPush Troubleshooter'; // Default title
    var body = 'Could not get the content'; // Default body
    if (payload == 'org.unifiedpush.TEST_NOTIF') {
      body = 'Test notification received.';
    } else {
      try {
        // Try to decode title and message (JSON)
        final decodedMessage = decodeMessageContentsUri(payload);
        title = decodedMessage['title'] ?? title;
        body = decodedMessage['message'] ?? body;
      } catch (e) {
        // If decoding fails, use plain payload as body
        body = payload.isNotEmpty ? payload : 'Empty message';
      }
    }

    if (!_notificationInitialized) await _initNotifications();

    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'UP-Example',
      'UP-Example',
      playSound: false,
      importance: Importance.max,
      priority: Priority.high,
    );
    const platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().microsecondsSinceEpoch % 100000000,
      title,
      body,
      platformChannelSpecifics,
      payload: 'No_Sound',
    );
    return true;
  }

  static FutureOr<void> _initNotifications() async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      'notification_icon',
    );
    const initializationSettingsLinux = LinuxInitializationSettings(
      defaultActionName: 'open',
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      linux: initializationSettingsLinux,
    );
    _notificationInitialized =
        await _flutterLocalNotificationsPlugin.initialize(
          initializationSettings,
        ) ??
        false;
  }
}
