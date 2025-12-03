import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/global.dart';
import 'package:keychat/service/storage.dart';

/// Browser configuration class with typed getters and setters
class BrowserConfig {
  BrowserConfig._();

  static final BrowserConfig _instance = BrowserConfig._();
  static BrowserConfig get instance => _instance;

  final RxMap<String, dynamic> _config = <String, dynamic>{}.obs;

  // Default values
  static const bool _defaultEnableHistory = true;
  static const bool _defaultEnableBookmark = true;
  static const bool _defaultEnableRecommend = true;
  static const int _defaultHistoryRetentionDays = 30;
  static const bool _defaultAutoSignEvent = true;
  static const bool _defaultShowFAB = true;
  static const String _defaultFabPosition = 'right';
  static const double _defaultFabHeight = 0.33;
  static const bool _defaultAdBlockEnabled = true;
  static const bool _defaultMiniAppTooltipShown = false;
  static const String _defaultSearchEngine = 'brave';

  /// Get default config map
  static Map<String, dynamic> get defaultConfig => {
    'enableHistory': _defaultEnableHistory,
    'enableBookmark': _defaultEnableBookmark,
    'enableRecommend': _defaultEnableRecommend,
    'historyRetentionDays': _defaultHistoryRetentionDays,
    'autoSignEvent': _defaultAutoSignEvent,
    'showFAB': _defaultShowFAB,
    'fabPosition': _defaultFabPosition,
    'fabHeight': _defaultFabHeight,
    'adBlockEnabled': _defaultAdBlockEnabled,
    'miniAppTooltipShown': _defaultMiniAppTooltipShown,
    'searchEngine': _defaultSearchEngine,
  };

  /// Initialize the config from storage
  Future<void> init() async {
    var localConfig = Storage.getString(KeychatGlobal.browserConfig);
    if (localConfig == null) {
      localConfig = jsonEncode(defaultConfig);
      await Storage.setString(KeychatGlobal.browserConfig, localConfig);
    }
    _config.value = jsonDecode(localConfig) as Map<String, dynamic>;
  }

  Future<void> hideTooltipPermanently() async {
    if (!showMiniAppTooltip) return;
    await set('miniAppTooltipShown', true);
  }

  /// Save config to storage
  Future<void> _save() async {
    await Storage.setString(KeychatGlobal.browserConfig, jsonEncode(_config));
    _config.refresh();
  }

  /// Generic setter for any config key
  Future<void> set(String key, dynamic value) async {
    _config[key] = value;
    await _save();
  }

  /// Generic getter for any config key
  dynamic get(String key) => _config[key];

  /// Get the raw config map (for Obx reactivity)
  RxMap<String, dynamic> get rawConfig => _config;

  // Typed Getters
  bool get enableHistory =>
      _config['enableHistory'] as bool? ?? _defaultEnableHistory;

  bool get enableBookmark =>
      _config['enableBookmark'] as bool? ?? _defaultEnableBookmark;

  bool get enableRecommend =>
      _config['enableRecommend'] as bool? ?? _defaultEnableRecommend;

  int get historyRetentionDays =>
      _config['historyRetentionDays'] as int? ?? _defaultHistoryRetentionDays;

  bool get autoSignEvent =>
      _config['autoSignEvent'] as bool? ?? _defaultAutoSignEvent;

  bool get showFAB => _config['showFAB'] as bool? ?? _defaultShowFAB;

  String get fabPosition =>
      _config['fabPosition'] as String? ?? _defaultFabPosition;

  double get fabHeight =>
      (_config['fabHeight'] as num?)?.toDouble() ?? _defaultFabHeight;

  bool get adBlockEnabled =>
      _config['adBlockEnabled'] as bool? ?? _defaultAdBlockEnabled;

  /// Returns true if the tooltip should be shown (i.e., not yet dismissed)
  bool get showMiniAppTooltip =>
      !(_config['miniAppTooltipShown'] as bool? ?? _defaultMiniAppTooltipShown);

  String get searchEngine =>
      _config['searchEngine'] as String? ?? _defaultSearchEngine;

  // Typed Setters
  Future<void> setEnableHistory(bool value) => set('enableHistory', value);

  Future<void> setEnableBookmark(bool value) => set('enableBookmark', value);

  Future<void> setEnableRecommend(bool value) => set('enableRecommend', value);

  Future<void> setHistoryRetentionDays(int value) =>
      set('historyRetentionDays', value);

  Future<void> setAutoSignEvent(bool value) => set('autoSignEvent', value);

  Future<void> setShowFAB(bool value) => set('showFAB', value);

  Future<void> setFabPosition(String value) => set('fabPosition', value);

  Future<void> setFabHeight(double value) => set('fabHeight', value);

  Future<void> setAdBlockEnabled(bool value) => set('adBlockEnabled', value);

  Future<void> setSearchEngine(String value) => set('searchEngine', value);
}
