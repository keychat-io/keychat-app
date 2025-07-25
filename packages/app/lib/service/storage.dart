// lib/common/Storage.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageKeyString {
  static String onboarding = 'onboarding';
  static String themeMode = 'themeMode';
  static String settingNotifyStatus = 'settingNotifyStatus';
  static String notificationFCMToken = 'notificationFCMToken';
  static String desktopRoomListWidth = 'desktopRoomListWidth';

  static String homeSelectedTabIndex = 'homeSelectedTabIndex';
  static String dbVersion = 'dbVersion';
  static String navigationLocation = "navigationLocation";
  static String getViewKeychatFutures = "getViewKeychatFutures";
  static String autoDeleteMessageDays = "autoDeleteMessageDays";
  static String lastMessageAt = "lastMessageAt";
  static String defaultWebRTCServers = "defaultWebRTCServers";
  static String relayMessageFeeConfig = "relayMessageFeeConfig";
  static String relayFileFeeConfig = "relayFileFeeConfig";

  static String tipsAddFriends = "tipsAddFriends";
  static String taskCreateIdentity = "taskCreateAIIdentity";
  static String taskCreateRoom = "taskCreateRoom";

  static String dbBackupPwd = "dbBackupPwd";
  static String selectedMediaServer = "selectedMediaServer";
  static String mediaServers = "mediaServers";

  static const String desktopBrowserSidebarWidth =
      'desktop_browser_sidebar_width';

  static String getSignalAliceKey(String myPubkey, String bobPubkey) {
    return "aliceKey:$myPubkey-$bobPubkey";
  }

  static String defaultSelectedTabIndex = 'defaultSelectedTabIndex';
  static String selectedTabIndex = 'selectedTabIndex';
  static String blossomProtocolServers = 'blossomProtocolServers';
  static String selectedPaymentPubkey = 'selectedPaymentPubkey';

  // mls group
  static const String mlsStates = 'mlsStates';
  static const String mlsPKIdentity = 'mlsPKIdentity';
  static const String mlsPKTimestamp = 'mlsPKTimestamp'; // Add this new key
}

class Storage {
  static Future<void> setString(key, value) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setString(key, value);
    // sp.setBool(key, value);
    // sp.setDouble(key, value);
    // sp.setInt(key, value);
    // sp.setStringList(key, value);
  }

  static Future<void> setBool(key, value) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setBool(key, value);
  }

  static Future<void> setStringList(String key, List<String> value) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setStringList(key, value);
  }

  static Future<void> setInt(String key, int value) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setInt(key, value);
  }

  static Future<int?> getInt(String key) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    return sp.getInt(key);
  }

  static Future<int> getIntOrZero(String key) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    var res = sp.getInt(key);
    if (res == null) return 0;
    return res;
  }

  static Future<String?> getString(key) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    return sp.getString(key);
  }

  static Future<bool?> getBool(key) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    return sp.getBool(key);
  }

  static Future<List<String>> getStringList(key) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    return sp.getStringList(key) ?? [];
  }

  static Future<void> removeString(key) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.remove(key);
  }

  static Future<void> clearAll() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.clear();
  }

  static Future<void> setLocalStorageMap(String key, Map sourceMap) async {
    String? res = await Storage.getString(key);
    Map map = {};
    if (res != null) {
      map = jsonDecode(res);
    }
    for (var entry in sourceMap.entries) {
      map[entry.key] = entry.value.toJson();
    }
    await Storage.setString(key, jsonEncode(map));
  }

  static Future<Map> getLocalStorageMap(String key) async {
    String? res = await Storage.getString(key);
    Map map = {};
    if (res != null) {
      try {
        map = jsonDecode(res);
        return map;
      } catch (e) {
        return {};
      }
    }
    return {};
  }
}
