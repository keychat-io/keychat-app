import 'dart:async' show TimeoutException;

import 'package:dio/dio.dart' show Dio, DioException;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/firebase_options.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (dotenv.get('FCM_API_KEY', fallback: '') != '') {
    if (Firebase.apps.isEmpty) {
      final app = await Firebase.initializeApp(
        name: GetPlatform.isAndroid ? 'keychat-bg' : null,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      logger.i('Firebase initialized in background: ${app.name}');
    }
    debugPrint('Handling a background message: ${message.messageId}');
  }
}

class NotifyService {
  // Avoid self instance
  // Avoid self instance
  NotifyService._();
  static NotifyService? _instance;
  static NotifyService get instance => _instance ??= NotifyService._();

  String? fcmToken;
  Future<bool> addPubkeys(
    List<String> toAddPubkeys, [
    List<String> toRemovePubkeys = const [],
  ]) async {
    if (fcmToken == null) return false;
    final res = await checkAllNotifyPermission();
    if (!res) return false;
    final relays = Get.find<WebsocketService>().getActiveRelayString();
    if (relays.isEmpty) return false;
    try {
      final res = await Dio().post(
        '${KeychatGlobal.notifycationServer}/add',
        data: {
          'deviceId': fcmToken,
          'pubkeys': toAddPubkeys,
          'toRemove': toRemovePubkeys,
          'relays': relays,
        },
      );
      logger.i('addPubkeys $toAddPubkeys, response: ${res.data}');
      return res.data['data'] is! bool || res.data['data'] as bool;
    } on DioException catch (e) {
      logger.e('addPubkeys error: ${e.response?.data}', error: e);
    }
    return false;
  }

  Future<String> calculateHash(List<String> array) async {
    final sortedStrings = List<String>.from(array)..sort();
    final joinedArray = sortedStrings.join();
    return rust_nostr.sha256Hash(data: joinedArray);
  }

  Future<bool> checkAllNotifyPermission() async {
    final isGrant = await isNotifyPermissionGrant();
    if (!isGrant) return false;

    final enable = Get.find<HomeController>().notificationStatus.value;
    if (!enable) return false;
    return true;
  }

  Future<bool> checkHashcode(String playerId, String hashcode) async {
    try {
      final res = await Dio().get(
        '${KeychatGlobal.notifycationServer}/hashcode?play_id=$playerId',
      );
      return hashcode == res.data['data'];
    } catch (e, s) {
      logger.e('checkPushed', error: e, stackTrace: s);
    }
    return false;
  }

  Future<void> clearAll() async {
    if (fcmToken == null) return;
    fcmToken = null;
    try {
      final res = await Dio().post(
        '${KeychatGlobal.notifycationServer}/delete',
        data: {'deviceId': fcmToken},
      );
      logger.i('clearAll success: ${res.data}');
    } catch (e, s) {
      logger.e('clearAll', error: e, stackTrace: s);
    }
  }

  Future<bool> isNotifyPermissionGrant() async {
    if (GetPlatform.isLinux || GetPlatform.isWindows) {
      logger.i('Notification not working on windows and linux');
      return false;
    }

    try {
      if (GetPlatform.isMacOS) {
        // macOS must use Firebase
        final s = await FirebaseMessaging.instance.getNotificationSettings();
        return s.authorizationStatus == AuthorizationStatus.authorized ||
            s.authorizationStatus == AuthorizationStatus.provisional;
      } else {
        // Android and iOS use permission_handler
        final status = await Permission.notification.status;
        return status.isGranted || status.isProvisional;
      }
    } catch (e) {
      logger.e('hasNotifyPermission error', error: e);
      return false;
    }
  }

  /// Request notification permission from user
  /// Returns true if permission is granted
  Future<bool> requestNotifyPermission() async {
    if (GetPlatform.isLinux || GetPlatform.isWindows) {
      logger.i('Notification not working on windows and linux');
      return false;
    }

    try {
      // Try Firebase first
      final settings = await FirebaseMessaging.instance.requestPermission(
        provisional: true,
      );
      logger.i('Notification Status: ${settings.authorizationStatus.name}');

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      // Fallback to permission_handler if Firebase fails
      logger.w(
        'Firebase permission request failed, using permission_handler',
        error: e,
      );
      try {
        final status = await Permission.notification.request();
        return status.isGranted;
      } catch (e2) {
        logger.e('requestNotifyPermission error', error: e2);
        return false;
      }
    }
  }

  // Listening Keys: identity pubkey, mls group pubkey, signal chat receive key, onetime key
  Future<void> syncPubkeysToServer({bool checkUpload = false}) async {
    final isGrant = await checkAllNotifyPermission();
    if (!isGrant) return;
    final toRemovePubkeys = await ContactService.instance.getAllToRemoveKeys();
    if (toRemovePubkeys.isNotEmpty) {
      await ContactService.instance.removeAllToRemoveKeys();
    }

    final enable = Get.find<HomeController>().notificationStatus.value;
    if (!enable) return;
    fcmToken ??= await _getFCMToken();
    if (fcmToken == null) return;

    final idPubkeys = await IdentityService.instance.getListenPubkeys(
      skipMute: true,
    );
    final pubkeys2 = await IdentityService.instance.getRoomPubkeysSkipMute();

    final relays = await RelayService.instance.getEnableList();
    if (toRemovePubkeys.isNotEmpty) {
      await removePubkeys(toRemovePubkeys);
    }
    if (checkUpload) {
      final hashcode = await calculateHash([
        ...idPubkeys,
        ...pubkeys2,
      ]);
      final hasUploaded = await checkHashcode(
        fcmToken!,
        hashcode,
      );
      if (hasUploaded) return;
    }
    final map = {
      'kind': 4,
      'deviceId': fcmToken,
      'pubkeys': [...idPubkeys, ...pubkeys2],
      'relays': relays,
    };
    try {
      final res = await Dio().post(
        '${KeychatGlobal.notifycationServer}/init',
        data: map,
      );

      logger.i('initNofityConfig ${res.data}');
    } on DioException catch (e, s) {
      logger.e('initNofityConfig ${e.response}', error: e, stackTrace: s);
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  /// Initialize Firebase if not already initialized
  Future<void> _initializeFirebase() async {
    if (dotenv.get('FCM_API_KEY', fallback: '') == '') {
      logger.w('FCM_API_KEY not configured, skipping Firebase initialization');
      return;
    }

    if (Firebase.apps.isNotEmpty) {
      logger.d('Firebase already initialized');
      return;
    }

    try {
      await Firebase.initializeApp(
        name: GetPlatform.isAndroid ? 'keychat' : null,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      logger.i('Firebase initialized successfully');
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } catch (error) {
      logger.e('Firebase initialize failed: $error');
      rethrow;
    }
  }

  /// Setup FCM message listeners
  void _setupFCMListeners() {
    // fcm onMessage listen
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        logger.i('notification: ${message.data}');
        if (message.notification != null) {
          debugPrint('notification: ${message.notification?.body}');
        }
      },
      onError: (Object e) {
        logger.e('onMessage', error: e);
      },
      onDone: () {
        logger.i('onMessage done');
      },
    );

    // fcm onMessageOpenedApp listen
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
    // fcm onTokenRefresh listen
    FirebaseMessaging.instance.onTokenRefresh
        .listen((newToken) {
          logger.i('onTokenRefresh: $newToken');
          fcmToken = newToken;
          Storage.setString(StorageKeyString.notificationFCMToken, newToken);
          syncPubkeysToServer();
        })
        .onError((Object err, StackTrace stackTrace) {
          logger.e('onTokenRefresh', error: err, stackTrace: stackTrace);
        });
  }

  /// Get FCM token with timeout handling
  Future<String?> _getFCMToken() async {
    try {
      final apnsToken = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 8),
        onTimeout: () async {
          final cachedToken = Storage.getString(
            StorageKeyString.notificationFCMToken,
          );
          loggerNoLine.d('Load FCMToken from local: $cachedToken');
          if (cachedToken != null) return cachedToken;

          Get.showSnackbar(
            GetSnackBar(
              snackPosition: SnackPosition.TOP,
              icon: const Icon(Icons.error, color: Colors.amber, size: 24),
              duration: const Duration(seconds: 8),
              onTap: (snack) {
                Get.back<void>();
              },
              title: 'Notification Init Error',
              message: '''
Timeout to call device-provisioning.googleapis.com.
Fix:
1. Check your network connection.
2. Restart the app.
''',
            ),
          );
          throw TimeoutException('FCMTokenTimeout');
        },
      );

      if (apnsToken != null) {
        await Storage.setString(
          StorageKeyString.notificationFCMToken,
          apnsToken,
        );
      }
      return apnsToken;
    } catch (e) {
      logger.e('getAPNSToken error: $e');
      return null;
    }
  }

  /// Initialize notification service
  /// This should be called:
  /// 1. On app startup (if user hasn't disabled notifications)
  /// 2. When user enables notifications in settings
  Future<void> init({bool requestPermission = false}) async {
    if (GetPlatform.isLinux || GetPlatform.isWindows) {
      logger.i('Notification not working on windows and linux');
      return;
    }

    logger.i('NotifyService init (requestPermission: $requestPermission)');
    final homeController = Get.find<HomeController>();

    // Check if user has disabled notifications in app settings
    final settingNotifyStatus = Storage.getIntOrZero(
      StorageKeyString.settingNotifyStatus,
    );
    if (settingNotifyStatus == NotifySettingStatus.disable) {
      logger.i('Notification disabled by user setting');
      homeController.notificationStatus.value = false;
      return;
    }

    // Initialize Firebase
    try {
      await _initializeFirebase();
    } catch (e) {
      logger.e('Failed to initialize Firebase', error: e);
      homeController.notificationStatus.value = false;
      return;
    }

    // Check or request permission
    var hasPermission = false;
    if (requestPermission) {
      hasPermission = await requestNotifyPermission();
    } else {
      hasPermission = await isNotifyPermissionGrant();
    }

    if (!hasPermission) {
      logger.i('Notification permission not granted');
      homeController.notificationStatus.value = false;
      return;
    }

    // Get FCM token
    fcmToken ??= await _getFCMToken();

    if (fcmToken == null) {
      if (GetPlatform.isMobile) {
        await EasyLoading.showError(
          'Failed to initialize notifications: Unable to obtain fcm token. Please check your network connection and try again.',
          duration: const Duration(seconds: 4),
        );
      }
      homeController.notificationStatus.value = false;
      return;
    }

    // Update status
    homeController.notificationStatus.value = true;
    if (settingNotifyStatus != NotifySettingStatus.enable) {
      await Storage.setInt(
        StorageKeyString.settingNotifyStatus,
        NotifySettingStatus.enable,
      );
    }

    // Handle initial message if app was opened from notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      handleMessage(initialMessage);
    }

    // Setup FCM listeners
    _setupFCMListeners();

    logger.i('fcmToken: $fcmToken');

    // Sync pubkeys to server
    await syncPubkeysToServer(checkUpload: true);
  }

  Future<bool> removePubkeys(List<String> pubkeys) async {
    if (fcmToken == null) return true;

    try {
      final res = await Dio().post(
        '${KeychatGlobal.notifycationServer}/remove',
        data: {'deviceId': fcmToken, 'pubkeys': pubkeys},
      );
      logger.i('removePubkeys ${res.data}');
      return true;
    } catch (e, s) {
      logger.e('removePubkeys', error: e, stackTrace: s);
    }
    return false;
  }

  // Handle message when app is in background or terminated
  // Open chat room if the message contains a pubkey
  Future<void> handleMessage(RemoteMessage message) async {
    if (message.data.isEmpty) return;
    if (message.data['pubkey'] != null) {
      final pubkey = message.data['pubkey'] as String;
      if (pubkey.isEmpty) {
        return;
      }
      if (!GetPlatform.isMobile) return;
      final room = await RoomService.instance.getRoomByMyReceiveKey(pubkey);
      if (room == null) {
        logger.e(
          'handleMessage: Room not found. pubkey: $pubkey, event id: ${message.data['id']}',
        );
        return;
      }
      final isCurrentPage = DBProvider.instance.isCurrentPage(room.id);
      if (!isCurrentPage) {
        await Utils.toNamedRoom(room);
      }
    }
  }
}

class NotifySettingStatus {
  static const int enable = 1;
  static const int disable = -1;
}
