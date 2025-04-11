import 'dart:async' show TimeoutException;

import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:dio/dio.dart' show Dio, DioException;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class NotifyService {
  static String? fcmToken;
  static Future<bool> addPubkeys(List<String> toAddPubkeys,
      [List<String> toRemovePubkeys = const []]) async {
    if (fcmToken == null) return false;
    bool res = await hasNotifyPermission();
    if (!res) return false;
    List<String> relays = Get.find<WebsocketService>().getActiveRelayString();
    if (relays.isEmpty) return false;
    try {
      var res =
          await Dio().post('${KeychatGlobal.notifycationServer}/add', data: {
        'deviceId': fcmToken,
        'pubkeys': toAddPubkeys,
        'toRemove': toRemovePubkeys,
        'relays': relays
      });
      logger.i('addPubkeys $toAddPubkeys, response: ${res.data}');
      return res.data['data'] ?? true;
    } on DioException catch (e) {
      logger.e('addPubkeys error: ${e.response?.data}', error: e);
    }
    return false;
  }

  static Future<String> calculateHash(List<String> array) async {
    List<String> sortedStrings = List.from(array)..sort();
    String joinedArray = sortedStrings.join('');
    return await rust_nostr.sha256Hash(data: joinedArray);
  }

  static Future<bool> checkAllNotifyPermission() async {
    bool isGrant = await NotifyService.hasNotifyPermission();
    if (!isGrant) return false;

    bool enable = Get.find<HomeController>().notificationStatus.value;
    if (!enable) return false;
    return true;
  }

  static Future<bool> checkHashcode(String playerId, String hashcode) async {
    try {
      var res = await Dio().get(
          '${KeychatGlobal.notifycationServer}/hashcode?play_id=$playerId');
      return hashcode == res.data['data'];
    } catch (e, s) {
      logger.e('checkPushed', error: e, stackTrace: s);
    }
    return false;
  }

  static clearAll() async {
    if (fcmToken == null) return;
    fcmToken == null;
    try {
      var res = await Dio().post('${KeychatGlobal.notifycationServer}/delete',
          data: {'deviceId': fcmToken});
      logger.i('clearAll success: ${res.data}');
    } catch (e, s) {
      logger.e('clearAll', error: e, stackTrace: s);
    }
  }

  static Future<bool> hasNotifyPermission() async {
    if (GetPlatform.isLinux || GetPlatform.isWindows) {
      logger.d('Notification not working on windows and linux');
      return false;
    }
    var s = await FirebaseMessaging.instance.getNotificationSettings();
    if (s.authorizationStatus == AuthorizationStatus.authorized) return true;
    return false;
  }

  // Listening Keys: identity pubkey, mls group pubkey, signal chat receive key, onetime key
  static syncPubkeysToServer({bool checkUpload = false}) async {
    bool isGrant = await NotifyService.checkAllNotifyPermission();
    if (!isGrant) return;
    List<String> toRemovePubkeys =
        await ContactService.instance.getAllToRemoveKeys();
    if (toRemovePubkeys.isNotEmpty) {
      await ContactService.instance.removeAllToRemoveKeys();
    }

    bool enable = Get.find<HomeController>().notificationStatus.value;
    if (!enable) return;
    if (fcmToken == null) return;

    List<String> idPubkeys =
        await IdentityService.instance.getListenPubkeys(skipMute: true);
    List<String> pubkeys2 =
        await IdentityService.instance.getRoomPubkeysSkipMute();

    List<String> relays = await RelayService.instance.getEnableList();
    if (toRemovePubkeys.isNotEmpty) {
      await removePubkeys(toRemovePubkeys);
    }
    if (checkUpload) {
      // OneSignal.Notifications.clearAll();
      String hashcode = await NotifyService.calculateHash(
          [...idPubkeys, ...pubkeys2, ...relays]);
      bool hasUploaded = await NotifyService.checkHashcode(fcmToken!, hashcode);

      if (hasUploaded) return;
    }
    var map = {
      "kind": 4,
      "deviceId": fcmToken,
      "pubkeys": [...idPubkeys, ...pubkeys2],
      "relays": relays
    };
    try {
      var res = await Dio()
          .post('${KeychatGlobal.notifycationServer}/init', data: map);

      logger.i('initNofityConfig ${res.data}');
    } on DioException catch (e, s) {
      logger.e('initNofityConfig ${e.response?.toString()}',
          error: e, stackTrace: s);
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  static requestPremissionAndInit() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: true,
      sound: true,
    );
    init();
  }

  static Future init() async {
    if (GetPlatform.isLinux || GetPlatform.isWindows) {
      logger.d('Notification not working on windows and linux');
      return;
    }
    var settings = await FirebaseMessaging.instance.getNotificationSettings();
    logger.i('Notification Status: ${settings.authorizationStatus.name}');
    // app setting
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    bool notDetermined =
        settings.authorizationStatus == AuthorizationStatus.notDetermined;
    int settingNotifyStatus =
        await Storage.getIntOrZero(StorageKeyString.settingNotifyStatus);
    var homeController = Get.find<HomeController>();

    if (settingNotifyStatus == NotifySettingStatus.disable && !notDetermined) {
      homeController.notificationStatus.value = false;
      return;
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      homeController.notificationStatus.value = false;
      Storage.setInt(
          StorageKeyString.settingNotifyStatus, NotifySettingStatus.disable);
      return;
    }
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      homeController.notificationStatus.value = true;
      Storage.setInt(
          StorageKeyString.settingNotifyStatus, NotifySettingStatus.enable);
      fcmToken = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 8), onTimeout: () async {
        fcmToken =
            await Storage.getString(StorageKeyString.notificationFCMToken);
        loggerNoLine.d('Load FCMToken from local: $fcmToken');
        if (fcmToken != null) return fcmToken;
        Get.showSnackbar(
          GetSnackBar(
              snackPosition: SnackPosition.TOP,
              icon: const Icon(Icons.error, color: Colors.amber, size: 24),
              duration: const Duration(seconds: 8),
              onTap: (snack) {
                Get.back();
              },
              title: 'Notification Init Error',
              message: '''Timeout to call device-provisioning.googleapis.com.
Fix:
1. Check your network connection.
2. Restart the app.
'''),
        );
        throw TimeoutException('FCMTokenTimeout');
      });
      // end get fcm timeout
      if (fcmToken != null) {
        Storage.setString(StorageKeyString.notificationFCMToken, fcmToken);
      }

      // fcm onMessage listen
      loggerNoLine.d('fcm onMessage listen');
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        logger.d('notification: ${message.data}');

        if (message.notification != null) {
          debugPrint('notification: ${message.notification?.body}');
        }
      }, onError: (e) {
        logger.e('onMessage', error: e);
      }, onDone: () {
        logger.d('onMessage done');
      });

      logger.i('fcmToken: $fcmToken');
      // fcm onTokenRefresh listen
      FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) {
        logger.i('onTokenRefresh: $fcmToken');
        NotifyService.fcmToken = fcmToken;
        NotifyService.syncPubkeysToServer(checkUpload: false);
      }).onError((err) {
        logger.e('onTokenRefresh', error: err);
      });

      await syncPubkeysToServer(checkUpload: true);
    }
  }

  static Future<bool> removePubkeys(List<String> pubkeys) async {
    if (fcmToken == null) return true;

    try {
      var res = await Dio().post('${KeychatGlobal.notifycationServer}/remove',
          data: {'deviceId': fcmToken, 'pubkeys': pubkeys});
      logger.i('removePubkeys ${res.data}');
      return true;
    } catch (e, s) {
      logger.e('removePubkeys', error: e, stackTrace: s);
    }
    return false;
  }

  // app online, do not push
  static void setOnlineStatus(bool status) async {
    bool enable = Get.find<HomeController>().notificationStatus.value;
    if (!enable) return;
    if (fcmToken == null) return;
    try {
      logger.i('setOnlineStatus $status');
      await Dio().post('${KeychatGlobal.notifycationServer}/appstatus',
          data: {'status': status ? 1 : -1, 'deviceId': fcmToken});
    } catch (e) {
      logger.e('${(e as DioException).response?.data}', error: e);
    }
  }

  static Future updateUserSetting(bool status) async {
    Get.find<HomeController>().notificationStatus.value = status;
    Get.find<HomeController>().notificationStatus.refresh();
    int intStatus = status ? 1 : -1;
    await Storage.setInt(StorageKeyString.settingNotifyStatus, intStatus);
    if (status) {
      await NotifyService.syncPubkeysToServer();
    } else {
      await NotifyService.clearAll();
    }
  }
}

class NotifySettingStatus {
  static const int enable = 1;
  static const int disable = -1;
}
