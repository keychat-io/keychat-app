import 'dart:convert' show utf8;

import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:dio/dio.dart' show Dio, DioException;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';

class NotifyService {
  static String? fcmToken;
  static Future<bool> addPubkeys(List<String> toAddPubkeys,
      [List<String> toRemovePubkeys = const []]) async {
    if (fcmToken == null) return false;
    List<String> relays = Get.find<WebsocketService>().getActiveRelayString();
    if (relays.isEmpty) return false;
    bool res = await checkAllNotifyPermission();
    if (!res) return false;
    try {
      var res =
          await Dio().post('${KeychatGlobal.notifycationServer}/add', data: {
        'deviceId': fcmToken,
        'pubkeys': toAddPubkeys,
        'toRemove': toRemovePubkeys,
        'relays': relays
      });
      logger.i('addPubkeys ${res.data}');
      return res.data['data'] ?? true;
    } on DioException catch (e, s) {
      logger.e('addPubkeys error: ${e.response?.data}',
          error: e, stackTrace: s);
    }
    return false;
  }

  static String calculateHash(List<String> array) {
    List<String> sortedStrings = List.from(array)..sort();
    String joinedArray = sortedStrings.join('');
    var bytes = utf8.encode(joinedArray); // data being hashed
    var digest = sha256.convert(bytes);
    return digest.toString();
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

  static deleteNofityConfig() async {
    if (fcmToken == null) return;
    try {
      var res = await Dio().post('${KeychatGlobal.notifycationServer}/delete',
          data: {'deviceId': fcmToken});
      logger.i('deleteNofityConfig ${res.data}');
    } catch (e, s) {
      logger.e('deleteNofityConfig', error: e, stackTrace: s);
    }
  }

  static Future<bool> hasNotifyPermission() async {
    var s = await FirebaseMessaging.instance.getNotificationSettings();

    if (s.authorizationStatus == AuthorizationStatus.denied) return false;
    if (s.authorizationStatus == AuthorizationStatus.authorized) return true;
    return false;
  }

  static initNofityConfig([bool checkUpload = false]) async {
    HomeController hc = Get.find<HomeController>();
    bool isGrant = await NotifyService.hasNotifyPermission();
    bool enableStatus = hc.notificationStatus.value && isGrant;
    if (!enableStatus) return;

    // logger.i('id: ${fcmToken}, enable: $isGrant');

    // OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    //   /// preventDefault to not display the notification
    //   event.preventDefault();

    //   if (hc.resumed) return;

    //   // Shared key group, if you switch out soon, you will receive the messages you send yourself.
    //   DateTime now = DateTime.now().subtract(const Duration(seconds: 3));
    //   if (hc.pausedTime != null && hc.pausedTime!.isBefore(now)) {
    //     /// notification.display() to display after preventing default
    //     event.notification.display();
    //   }
    // });
    List<String> toRemovePubkeys = await ContactService().getAllToRemoveKeys();
    if (toRemovePubkeys.isNotEmpty) {
      await ContactService().removeAllToRemoveKeys();
    }
    if (!GetPlatform.isMobile) return;

    bool enable = Get.find<HomeController>().notificationStatus.value;
    if (!enable) return;
    List<String> pubkeys =
        await IdentityService().getListenPubkeys(skipMute: true);
    List<String> pubkeys2 = await ContactService().getAllReceiveKeysSkipMute();

    if (pubkeys.isEmpty) return;

    List<String> relays = await RelayService().getEnableList();
    if (toRemovePubkeys.isNotEmpty) {
      await removePubkeys(toRemovePubkeys);
    }
    if (checkUpload) {
      // OneSignal.Notifications.clearAll();
      String hashcode =
          NotifyService.calculateHash([...pubkeys, ...pubkeys2, ...relays]);
      bool hasUploaded = await NotifyService.checkHashcode(fcmToken!, hashcode);

      if (hasUploaded) return;
    }

    var map = {
      "kind": 4,
      "deviceId": fcmToken,
      "pubkeys": [...pubkeys, ...pubkeys2],
      "relays": relays
    };
    try {
      var res = await Dio()
          .post('${KeychatGlobal.notifycationServer}/init', data: map);

      logger.i(
        'initNofityConfig ${res.data}',
      );
    } on DioException catch (e, s) {
      logger.e('initNofityConfig ${e.response?.toString()}',
          error: e, stackTrace: s);
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  // static Future startup() async {
  //   int settingNotifyStatus =
  //       await Storage.getIntOrZero(StorageKeyString.settingNotifyStatus);
  //   if (settingNotifyStatus == 0)
  // }

  static Future init() async {
    // int settingNotifyStatus =
    //     await Storage.getIntOrZero(StorageKeyString.settingNotifyStatus);
    // user click disable and config is denied
    var s = await FirebaseMessaging.instance.getNotificationSettings();
    if (s.authorizationStatus == AuthorizationStatus.denied) return;
    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    logger.i('id: ${settings.authorizationStatus.name}');
    HomeController hc = Get.find<HomeController>();

    // user denied
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      hc.notificationStatus.value = false;
      Storage.setInt(
          StorageKeyString.settingNotifyStatus, NotifyStatus.disable);
      return;
    }
    hc.notificationStatus.value = true;

    // user's token
    fcmToken = await FirebaseMessaging.instance.getToken();
    logger.i('fcmToken: $fcmToken');

    Storage.setInt(StorageKeyString.settingNotifyStatus, NotifyStatus.enable);

    // OneSignal.Notifications.addPermissionObserver((state) async {
    //   logger.d("Has permission $state");
    //   hc.notificationStatus.value = state;

    //   Storage.setInt(StorageKeyString.settingNotifyStatus,
    //       state ? NotifyStatus.enable : NotifyStatus.disable);
    //   if (state) {
    //     Future.delayed(
    //         const Duration(seconds: 10), () => initNofityConfig(true));
    //   }
    // });
    // for init

    await initNofityConfig(true);
  }

  static Future<bool> removePubkeys(List<String> pubkeys) async {
    if (fcmToken == null) return false;

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
    if (!GetPlatform.isMobile) return;

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

  static Future updateNotificationUserSetting(bool status) async {
    Get.find<HomeController>().notificationStatus.value = status;
    int intStatus = status ? 1 : -1;
    await Storage.setInt(StorageKeyString.settingNotifyStatus, intStatus);
    if (status) {
      await NotifyService.initNofityConfig();
    } else {
      await NotifyService.deleteNofityConfig();
    }
    return;
  }
}

class NotifyStatus {
  static const int enable = 1;
  static const int disable = -1;
}
