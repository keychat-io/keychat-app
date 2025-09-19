import 'dart:convert';
import 'dart:io';

import 'package:app/utils.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageKeyString {
  static String onboarding = 'onboarding';
  static String themeMode = 'themeMode';
  static String settingNotifyStatus = 'settingNotifyStatus';
  static String notificationFCMToken = 'notificationFCMToken';
  static String desktopRoomListWidth = 'desktopRoomListWidth';

  static String homeSelectedTabIndex = 'homeSelectedTabIndex';
  static String dbVersion = 'dbVersion';
  static String navigationLocation = 'navigationLocation';
  static String getViewKeychatFutures = 'getViewKeychatFutures';
  static String autoDeleteMessageDays = 'autoDeleteMessageDays';
  static String lastMessageAt = 'lastMessageAt';
  static String defaultWebRTCServers = 'defaultWebRTCServers';
  static String relayMessageFeeConfig = 'relayMessageFeeConfig';
  static String relayFileFeeConfig = 'relayFileFeeConfig';

  static String tipsAddFriends = 'tipsAddFriends';
  static String taskCreateIdentity = 'taskCreateAIIdentity';
  static String taskCreateRoom = 'taskCreateRoom';

  static String dbBackupPwd = 'dbBackupPwd';
  static String selectedMediaServer = 'selectedMediaServer';
  static String mediaServers = 'mediaServers';

  static const String desktopBrowserSidebarWidth =
      'desktop_browser_sidebar_width';

  static const String desktopBrowserTabs = 'desktopBrowserTabs';

  static String getSignalAliceKey(String myPubkey, String bobPubkey) {
    return 'aliceKey:$myPubkey-$bobPubkey';
  }

  static String defaultSelectedTabIndex = 'defaultSelectedTabIndex';
  static String selectedTabIndex = 'selectedTabIndex';
  static String blossomProtocolServers = 'blossomProtocolServers';
  static String selectedPaymentPubkey = 'selectedPaymentPubkey';

  // mls group
  static const String mlsStates = 'mlsStates';
  static const String mlsPKIdentity = 'mlsPKIdentity';
  static const String mlsPKTimestamp = 'mlsPKTimestamp';

  static const String mobileKeepAlive = 'mobileKeepAlive';
  static const String biometricsAuthTime = 'biometricsAuthTime';

  static const String ecashDBVersion = 'ecashDBVersion';
  static const String upgradeToV2Tokens = 'upgradeToV2Tokens';
}

class Storage {
  static SharedPreferences? _sp;

  // Add a getter that ensures SharedPreferences is initialized
  static SharedPreferences get sp {
    if (_sp == null) {
      throw StateError('Storage not initialized. Call Storage.init() first.');
    }
    return _sp!;
  }

  static Future<void> init() async {
    try {
      _sp = await SharedPreferences.getInstance();
    } catch (error) {
      final appSupportDirectory = await getApplicationSupportDirectory();
      final appDataPath =
          path.join(appSupportDirectory.path, 'shared_preferences.json');
      logger.e(
          'Failed to load the preferences file at $appDataPath. Attempting to repair it.');
      await _repairPreferences(appDataPath);

      try {
        _sp = await SharedPreferences.getInstance();
      } catch (error) {
        logger.e(
            'Failed to repair the preferences file. Deleting the file and proceeding with a fresh configuration.');
        await File(appDataPath).delete();
        _sp = await SharedPreferences.getInstance();
      }
    }
  }

  static Future<void> _repairPreferences(String appDataPath) async {
    final List<int> contents = await File(appDataPath).readAsBytes();
    final contentsGrowable = List<int>.from(contents); // Make the list growable

    // Remove any NUL characters
    contentsGrowable.removeWhere((item) => item == 0);

    await File(appDataPath).writeAsBytes(contentsGrowable);
  }

  static Future<void> setString(String key, String value) async {
    await sp.setString(key, value);
  }

  static Future<void> setBool(String key, bool value) async {
    await sp.setBool(key, value);
  }

  static Future<void> setStringList(String key, List<String> value) async {
    await sp.setStringList(key, value);
  }

  static Future<void> setInt(String key, int value) async {
    await sp.setInt(key, value);
  }

  static int? getInt(String key) {
    return sp.getInt(key);
  }

  static int getIntOrZero(String key) {
    final res = sp.getInt(key);
    if (res == null) return 0;
    return res;
  }

  static String? getString(String key) {
    return sp.getString(key);
  }

  static bool? getBool(String key) {
    return sp.getBool(key);
  }

  static List<String> getStringList(String key) {
    return sp.getStringList(key) ?? [];
  }

  static Future<void> remove(String key) async {
    await sp.remove(key);
  }

  static Future<void> clearAll() async {
    await sp.clear();
  }

  static Future<void> setLocalStorageMap(String key, Map sourceMap) async {
    final res = Storage.getString(key);
    Map map = {};
    if (res != null) {
      map = jsonDecode(res) as Map<String, dynamic>;
    }
    for (final entry in sourceMap.entries) {
      map[entry.key] = entry.value.toJson();
    }
    await Storage.setString(key, jsonEncode(map));
  }

  static Future<Map> getLocalStorageMap(String key) async {
    final res = Storage.getString(key);
    Map map = {};
    if (res != null) {
      try {
        map = jsonDecode(res) as Map<String, dynamic>;
        return map;
      } catch (e) {
        return {};
      }
    }
    return {};
  }
}
