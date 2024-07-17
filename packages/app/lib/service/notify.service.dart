import 'dart:convert' show utf8;

import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/service/contact.service.dart';

import 'package:app/service/identity.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:dio/dio.dart' show Dio, DioException;
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotifyStatus {
  static const int enable = 1;
  static const int disable = -1;
}

class NotifyService {
  static String calculateHash(List<String> array) {
    List<String> sortedStrings = List.from(array)..sort();
    String joinedArray = sortedStrings.join('');
    var bytes = utf8.encode(joinedArray); // data being hashed
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  static initNofityConfig([bool checkUpload = false]) async {
    HomeController hc = Get.find<HomeController>();

    // await OneSignal.Notifications.requestPermission(true);
    // await OneSignal.User.pushSubscription.optIn();
    bool isGrant = await NotifyService.hasNotifyPermission();
    logger.i('id: ${OneSignal.User.pushSubscription.id}, enable: $isGrant');
    bool enableStatus = hc.notificationStatus.value && isGrant;
    if (!enableStatus) return;

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      /// preventDefault to not display the notification
      event.preventDefault();

      if (hc.resumed) return;

      // Shared key group, if you switch out soon, you will receive the messages you send yourself.
      DateTime now = DateTime.now().subtract(const Duration(seconds: 3));
      if (hc.pausedTime != null && hc.pausedTime!.isBefore(now)) {
        /// notification.display() to display after preventing default
        event.notification.display();
      }
    });
    List<String> toRemovePubkeys = await ContactService().getAllToRemoveKeys();
    if (toRemovePubkeys.isNotEmpty) {
      await ContactService().removeAllToRemoveKeys();
    }
    if (!GetPlatform.isMobile) return;

    if (OneSignal.User.pushSubscription.id == null) {
      return;
    }
    bool enable = Get.find<HomeController>().notificationStatus.value;
    if (!enable) return;

    OneSignal.User.pushSubscription.optIn();
    List<String> pubkeys =
        await IdentityService().getListenPubkeys(skipMute: true);
    List<String> pubkeys2 = await ContactService().getAllReceiveKeysSkipMute();

    if (pubkeys.isEmpty) return;

    List<String> relays = await RelayService().getEnableList();
    if (toRemovePubkeys.isNotEmpty) {
      await removePubkeys(toRemovePubkeys);
    }
    if (checkUpload) {
      OneSignal.Notifications.clearAll();
      String hashcode =
          NotifyService.calculateHash([...pubkeys, ...pubkeys2, ...relays]);
      bool hasUploaded = await NotifyService.checkHashcode(
          OneSignal.User.pushSubscription.id!, hashcode);

      if (hasUploaded) return;
    }

    var map = {
      "kind": 4,
      "deviceId": OneSignal.User.pushSubscription.id,
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

  static deleteNofityConfig() async {
    if (OneSignal.User.pushSubscription.id == null) return;
    try {
      var res = await Dio().post('${KeychatGlobal.notifycationServer}/delete',
          data: {'deviceId': OneSignal.User.pushSubscription.id});
      logger.i('deleteNofityConfig ${res.data}');
    } catch (e, s) {
      logger.e('deleteNofityConfig', error: e, stackTrace: s);
    }
  }

  static Future<bool> removePubkeys(List<String> pubkeys) async {
    if (OneSignal.User.pushSubscription.id == null) return false;

    try {
      var res = await Dio().post('${KeychatGlobal.notifycationServer}/remove',
          data: {
            'deviceId': OneSignal.User.pushSubscription.id,
            'pubkeys': pubkeys
          });
      logger.i('removePubkeys ${res.data}');
      return true;
    } catch (e, s) {
      logger.e('removePubkeys', error: e, stackTrace: s);
    }
    return false;
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

  static Future<bool> addPubkeys(List<String> toAddPubkeys,
      [List<String> toRemovePubkeys = const []]) async {
    List<String> relays = Get.find<WebsocketService>().getActiveRelayString();
    if (relays.isEmpty) return false;
    bool res = await checkAllNotifyPermission();
    if (!res) return false;

    try {
      var res =
          await Dio().post('${KeychatGlobal.notifycationServer}/add', data: {
        'deviceId': OneSignal.User.pushSubscription.id,
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

  static Future<bool> hasNotifyPermission() async {
    var res = await OneSignal.Notifications.permissionNative();
    return res == OSNotificationPermission.authorized;
  }

  static Future<bool> checkAllNotifyPermission() async {
    if (!GetPlatform.isMobile) return false;
    bool isGrant = await NotifyService.hasNotifyPermission();
    if (!isGrant || OneSignal.User.pushSubscription.id == null) return false;

    bool enable = Get.find<HomeController>().notificationStatus.value;
    if (!enable) return false;
    return true;
  }

  static Future initOnesignal() async {
    if (!GetPlatform.isMobile) return;
    String signalAPPId = dotenv.get('ONE_SIGNAL_APP_ID');
    if (signalAPPId.isEmpty) return;
    OneSignal.Debug.setLogLevel(OSLogLevel.info);
    OneSignal.initialize(signalAPPId);
    HomeController hc = Get.find<HomeController>();

    await hasNotifyPermission();
    int settingNotifyStatus =
        await Storage.getIntOrZero(StorageKeyString.settingNotifyStatus);
    hc.notificationStatus.value = settingNotifyStatus == NotifyStatus.enable;

    OneSignal.Notifications.addPermissionObserver((state) async {
      logger.d("Has permission $state");
      hc.notificationStatus.value = state;

      Storage.setInt(StorageKeyString.settingNotifyStatus,
          state ? NotifyStatus.enable : NotifyStatus.disable);
      if (state) {
        await initNofityConfig(true);
      }
    });
    // for init
    if (settingNotifyStatus == 0) {
      bool res = await OneSignal.Notifications.requestPermission(false);
      settingNotifyStatus = res ? NotifyStatus.enable : NotifyStatus.disable;
      Storage.setInt(StorageKeyString.settingNotifyStatus, settingNotifyStatus);
    }

    if (settingNotifyStatus == NotifyStatus.disable ||
        await hasNotifyPermission() == false) {
      logger.d('OneSignal disable');
      return;
    }

    OneSignal.Notifications.addClickListener((event) {
      logger.d('NOTIFICATION CLICK LISTENER CALLED WITH EVENT: $event');
    });
    OneSignal.InAppMessages.addClickListener((event) {
      // logger.d('in app click ${event.result.jsonRepresentation()}');
      if (event.result.actionId == 'allow') {
        EasyThrottle.throttle('InAppMessagesAllow', const Duration(seconds: 1),
            () {
          NotifyService.updateNotificationUserSetting(true);
        });
      }
    });

    await initNofityConfig(true);
  }

  static Future updateNotificationUserSetting(bool status) async {
    Get.find<HomeController>().notificationStatus.value = status;
    int intStatus = status ? 1 : -1;
    await Storage.setInt(StorageKeyString.settingNotifyStatus, intStatus);
    if (status) {
      await NotifyService.initNofityConfig();
    } else {
      OneSignal.User.pushSubscription.optOut();
      await NotifyService.deleteNofityConfig();
    }
    return;
  }

  // app online, do not push
  static void setOnlineStatus(bool status) async {
    if (!GetPlatform.isMobile) return;

    OneSignal.Notifications.clearAll();
    bool enable = Get.find<HomeController>().notificationStatus.value;
    if (!enable) return;
    if (OneSignal.User.pushSubscription.id == null) return;
    try {
      logger.i('setOnlineStatus $status');
      await Dio().post('${KeychatGlobal.notifycationServer}/appstatus', data: {
        'status': status ? 1 : -1,
        'deviceId': OneSignal.User.pushSubscription.id
      });
    } catch (e) {
      logger.e('${(e as DioException).response?.data}', error: e);
    }
  }
}
