import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:app/controller/setting.controller.dart';
import 'package:app/desktop/DesktopController.dart';
import 'package:app/global.dart';
import 'package:app/models/browser/browser_favorite.dart';
import 'package:app/models/browser/browser_history.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/page/browser/BrowserTabController.dart';
import 'package:app/page/browser/WebviewTab.dart';
import 'package:app/service/storage.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    hide Storage, WebResourceError;
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:url_launcher/url_launcher.dart';

class WebviewTabData {
  WebviewTabData(
      {required this.tab, required this.uniqueKey, required this.url});
  WebviewTab tab;
  String uniqueKey;
  String? title;
  String url;
  String? favicon;
}

class MultiWebviewController extends GetxController {
  final RxList<WebviewTabData> tabs = <WebviewTabData>[].obs;

  late TextEditingController textController;
  RxString title = 'Loading'.obs;
  RxString defaultSearchEngineObx = 'google'.obs;
  RxString input = ''.obs;
  RxDouble progress = 0.2.obs;
  int currentIndex = 0;

  RxSet<String> enableSearchEngine = <String>{}.obs;
  RxList<BrowserFavorite> favorites = <BrowserFavorite>[].obs;
  RxMap<String, dynamic> config = <String, dynamic>{}.obs;
  Map<String, InAppWebViewKeepAlive?> mobileKeepAlive = {};
  static const maxHistoryInHome = 12;

  late void Function(String url) urlChangeCallBack;

  WebViewEnvironment? webViewEnvironment;

  void addNewTab() {
    final uniqueId = generate64RandomHexChars(8);

    // use new tab if exist
    if (GetPlatform.isMobile) {
      for (var i = 0; i < tabs.length; i++) {
        final item = tabs[i];
        if (item.tab.initTitle == KeychatGlobal.newTab) {
          setCurrentTabIndex(i);
          return;
        }
      }
    }
    // allow multi new_tabs on desktop
    final tab = WebviewTab(
      uniqueKey: uniqueId,
      initUrl: KeychatGlobal.newTab,
      key: GlobalObjectKey(uniqueId),
      windowId: getLastWindowId(),
    );

    tabs.add(WebviewTabData(tab: tab, uniqueKey: uniqueId, url: tab.initUrl));
    setCurrentTabIndex(tabs.length - 1);
  }

  // for mobile
  void addOrSelectNewTab() {
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].url == KeychatGlobal.newTab) {
        setCurrentTabIndex(i);
        return;
      }
    }
    final uniqueId = generate64RandomHexChars(8);
    final tab = WebviewTab(
      uniqueKey: uniqueId,
      initUrl: KeychatGlobal.newTab,
      key: GlobalObjectKey(uniqueId),
      windowId: getLastWindowId(),
    );

    tabs.add(WebviewTabData(tab: tab, uniqueKey: uniqueId, url: tab.initUrl));
    setCurrentTabIndex(tabs.length - 1);
  }

  void removeByIndex(int removeIndex) {
    if (removeIndex >= 0) {
      tabs.remove(tabs[removeIndex]);
      if (tabs.isEmpty) {
        addNewTab();
        setCurrentTabIndex(0);
        saveDesktopTabs();
        return;
      }
    }
    if (removeIndex <= currentIndex) {
      setCurrentTabIndex(currentIndex - 1);
    } else {
      setCurrentTabIndex(currentIndex);
    }
    saveDesktopTabs();
  }

  void removeTab(String tabId) {
    var removeIndex = -1;
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].uniqueKey == tabId) {
        removeIndex = i;
        break;
      }
    }
    removeByIndex(removeIndex);
  }

  Future<void> launchWebview(
      {required String initUrl,
      String engine = 'google',
      String? defaultTitle}) async {
    if (initUrl.isEmpty) return;

    if (GetPlatform.isLinux) {
      logger.i('webview not working on linux');
      if (!await launchUrl(Uri.parse(initUrl))) {
        throw Exception('Could not launch $initUrl');
      }
      return;
    }
    var uniqueKey = generate64RandomHexChars(8);
    Uri? uri;
    var url = initUrl;
    if (initUrl.startsWith('http') == false) {
      // try: domain.com
      final isDomain = Utils.isDomain(initUrl);
      // start search engine
      if (isDomain) {
        url = 'https://$url';
      } else {
        final engine0 = engine.toLowerCase();
        switch (engine0) {
          case 'google':
            url = 'https://www.google.com/search?q=$url';
          case 'brave':
            url = 'https://search.brave.com/search?q=$url';
          case 'startpage':
            url = 'https://www.startpage.com/sp/search?q=$url';
          case 'searxng':
            url = 'https://searx.tiekoetter.com/search?q=$url';
        }
      }
    }
    uri = Uri.tryParse(url);
    if (uri == null) return;
    if (GetPlatform.isMobile) {
      uniqueKey = uri.host;
      await Get.to<void>(
          () => WebviewTab(
                initUrl: initUrl,
                initTitle: title.value,
                uniqueKey: uniqueKey, // for close controller
                windowId: 0,
                isCache: mobileKeepAlive.containsKey(uniqueKey),
                keepAlive: mobileKeepAlive[uniqueKey],
              ),
          transition: Transition.cupertino);
      return;
    }
    // for desktop
    final tab = WebviewTab(
      uniqueKey: uniqueKey,
      initUrl: initUrl,
      key: GlobalObjectKey(uniqueKey),
      windowId: getLastWindowId(),
    );
    if (GetPlatform.isDesktop) {
      if (Get.find<DesktopController>().sidebarXController.selectedIndex != 1) {
        Get.find<DesktopController>().sidebarXController.selectIndex(1);
      }
    }
    if (tabs[currentIndex].url == KeychatGlobal.newTab &&
        currentIndex != tabs.length - 1) {
      tabs
        ..removeAt(currentIndex)
        ..insert(currentIndex,
            WebviewTabData(tab: tab, uniqueKey: uniqueKey, url: tab.initUrl));
      setCurrentTabIndex(currentIndex);

      await saveDesktopTabs();
      return;
    }
    if (tabs.isNotEmpty && tabs.last.url == KeychatGlobal.newTab) {
      tabs.insert(tabs.length - 1,
          WebviewTabData(tab: tab, uniqueKey: uniqueKey, url: tab.initUrl));
      setCurrentTabIndex(tabs.length - 2);
    } else {
      tabs.add(
          WebviewTabData(tab: tab, uniqueKey: uniqueKey, url: tab.initUrl));
      setCurrentTabIndex(tabs.length - 1);
    }

    await saveDesktopTabs();
  }

  void setCurrentTabIndex(int index) {
    var newIndex = index;
    if (newIndex < 0 || newIndex >= tabs.length) {
      newIndex = 0;
    }
    currentIndex = newIndex;
    checkCurrentControllerAlive();
    updatePageTabIndex(newIndex);
  }

  void Function(int) updatePageTabIndex = (index) {};

  int getLastWindowId() {
    var windowId = 0;
    for (final item in tabs) {
      if (item.tab.windowId > windowId) {
        windowId = item.tab.windowId + 1;
      }
    }
    return windowId;
  }

  Future<void> loadConfig() async {
    var localConfig = Storage.getString(KeychatGlobal.browserConfig);
    if (localConfig == null) {
      localConfig = jsonEncode({
        'enableHistory': true,
        'enableBookmark': true,
        'enableRecommend': true,
        'historyRetentionDays': 30,
        'autoSignEvent': true,
      });
      await Storage.setString('browserConfig', localConfig);
    }
    config.value = jsonDecode(localConfig) as Map<String, dynamic>;

    // text zoom
    final textSize = Storage.getInt(KeychatGlobal.browserTextSize);
    if (textSize != null) {
      kInitialTextSize.value = textSize;
    }
  }

  Future<void> setConfig(String key, dynamic value) async {
    config[key] = value;
    await Storage.setString('browserConfig', jsonEncode(config));
    config.refresh();
  }

  BrowserHistory? lastHistory;
  Future<void> addHistory(String url, String title, [String? favicon]) async {
    if (!(config['enableHistory'] as bool)) return;

    if (lastHistory != null) {
      if (lastHistory!.url == url) {
        final now = DateTime.now();
        final lastVisit = lastHistory!.createdAt;
        if (now.difference(lastVisit).inMinutes < 1) {
          return;
        }
      }
    }
    final history = BrowserHistory(url: url, title: title, favicon: favicon);
    lastHistory = history;
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserHistorys.put(history);
    });
  }

  Future<void> addSearchEngine(String engine) async {
    enableSearchEngine.add(engine);
    await Storage.setStringList('searchEngine', enableSearchEngine.toList());
  }

  void initBrowser() {
    title.value = 'Loading';
    progress.value = 0.0;
  }

  Future<void> loadFavorite() async {
    favorites.value = await BrowserFavorite.getAll();
  }

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }

  @override
  Future<void> onInit() async {
    textController = TextEditingController();
    textController.addListener(() {
      input.value = textController.text.trim();
    });

    // load search engine
    defaultSearchEngineObx.value =
        Storage.getString('defaultSearchEngine') ?? defaultSearchEngine;

    await loadConfig();
    await loadKeepAlive(isInit: true);
    unawaited(loadFavorite());
    unawaited(initWebview());
    unawaited(deleteOldHistories());
    await loadDesktopTabs();
    if (tabs.isEmpty && GetPlatform.isDesktop) {
      addNewTab();
    }
    super.onInit();
  }

  Future<void> deleteOldHistories() async {
    if (!(config['enableHistory'] as bool)) return;

    final retentionDays = config['historyRetentionDays'] as int? ?? 30;
    final thresholdDate =
        DateTime.now().subtract(Duration(days: retentionDays));

    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserHistorys
          .filter()
          .createdAtLessThan(thresholdDate)
          .deleteAll();
    });
  }

  Future<void> initWebview() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final availableVersion = await WebViewEnvironment.getAvailableVersion();
      assert(availableVersion != null,
          'Failed to find an installed WebView2 Runtime or non-stable Microsoft Edge installation.');
      final browserCacheFolder =
          Get.find<SettingController>().browserCacheFolder;
      webViewEnvironment = await WebViewEnvironment.create(
          settings:
              WebViewEnvironmentSettings(userDataFolder: browserCacheFolder));
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
    }
  }

  Future<void> removeSearchEngine(String engine) async {
    enableSearchEngine.remove(engine);
    await Storage.setStringList('searchEngine', enableSearchEngine.toList());
  }

  Map<String, String> cachedFavicon = {};
  Future<String?> getFavicon(
      InAppWebViewController controller, String host) async {
    if (cachedFavicon.containsKey(host)) {
      return cachedFavicon[host];
    }
    try {
      final favicons = await controller.getFavicons().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('Favicon request timed out');
          return [];
        },
      );
      Favicon? favicon;
      if (favicons.isNotEmpty) {
        favicon = favicons.firstWhere(
          (favicon) => favicon.url.toString().endsWith('.png'),
          orElse: () => favicons.first,
        );
      }
      cachedFavicon[host] = favicon?.url.toString() ?? '';
      return favicon?.url.toString();
    } catch (e) {
      debugPrint('Error getting favicon: $e');
      return null;
    }
  }

  Future<void> saveDesktopTabs() async {
    if (!GetPlatform.isDesktop) return;

    final List<Map<String, dynamic>> tabData = tabs
        .map((tab) => {
              'url': tab.url,
              'title': tab.title ?? '',
              'favicon': tab.favicon,
            })
        .toList();

    await Storage.setString(
        StorageKeyString.desktopBrowserTabs, jsonEncode(tabData));
    logger.d('Saved ${tabData.length} desktop tabs');
  }

  void saveDesktopTabsDebounced() {
    if (!GetPlatform.isDesktop) return;
    EasyDebounce.debounce(
      'saveDesktopTabs',
      const Duration(seconds: 1),
      saveDesktopTabs,
    );
  }

  Future<void> loadDesktopTabs() async {
    if (!GetPlatform.isDesktop) return;

    try {
      final savedTabs = Storage.getString(StorageKeyString.desktopBrowserTabs);
      if (savedTabs == null || savedTabs.isEmpty) return;

      final tabData = jsonDecode(savedTabs) as List<dynamic>;
      logger.d('Loading ${tabData.length} desktop tabs');

      for (final (data as Map) in tabData) {
        final url = (data['url'] ?? '') as String;
        final title = (data['title'] ?? '') as String;
        final favicon = data['favicon'] as String?;

        if (url.isNotEmpty && url != KeychatGlobal.newTab) {
          final uniqueId = generate64RandomHexChars(8);
          final tab = WebviewTab(
            uniqueKey: uniqueId,
            initUrl: url,
            key: GlobalObjectKey(uniqueId),
            windowId: getLastWindowId(),
          );

          final tabData = WebviewTabData(
            tab: tab,
            uniqueKey: uniqueId,
            url: url,
          )
            ..title = title.isNotEmpty ? title : null
            ..favicon = favicon;

          tabs.add(tabData);
        }
      }

      // Add a new tab if no tabs were loaded
      if (tabs.isEmpty) {
        addNewTab();
      } else {
        setCurrentTabIndex(0);
      }
    } catch (e) {
      logger.e('Error loading desktop tabs: $e');
      // If loading fails, just add a new tab
      if (tabs.isEmpty) {
        addNewTab();
      }
    }
  }

  void setTabData(
      {required String uniqueId,
      required String url,
      String? title,
      String? favicon}) {
    final tabIndex = tabs.indexWhere((tab) => tab.uniqueKey == uniqueId);
    if (tabIndex >= 0) {
      if (title != null) {
        tabs[tabIndex].title = title;
      }
      tabs[tabIndex].url = url;
      if (favicon != null) {
        tabs[tabIndex].favicon = favicon;
      }
      tabs.refresh(); // Trigger UI update since we're using GetX

      saveDesktopTabsDebounced();
    }
  }

  WebviewTabData? getTab(String uniqueKey) {
    return tabs.firstWhereOrNull((e) => e.uniqueKey == uniqueKey);
  }

  void updateTabData({required String uniqueId, required String url}) {}

  WebviewTabController getOrCreateController(
      String initUrl, String? initTitle, String uniqueKey) {
    // multi window on desktop
    if (GetPlatform.isDesktop) {
      return Get.put(WebviewTabController(uniqueKey, initUrl, initTitle),
          tag: uniqueKey);
    }
    //
    try {
      final controller = Get.find<WebviewTabController>(tag: uniqueKey);
      logger.i('found controller $uniqueKey');
      return controller;
    } catch (e) {
      // permanent. manaully to delete
      return Get.put(WebviewTabController(uniqueKey, initUrl, initTitle),
          tag: uniqueKey);
    }
  }

  void setTabDataFavicon({required String uniqueId, required String favicon}) {
    final tabIndex = tabs.indexWhere((tab) => tab.uniqueKey == uniqueId);
    if (tabIndex >= 0) {
      tabs[tabIndex].favicon = favicon;
      tabs.refresh();
    }
  }

  RxInt kInitialTextSize = 100.obs;
  late String kTextSizeSourceJS = """
window.addEventListener('DOMContentLoaded', function(event) {
  document.body.style.textSizeAdjust = '$kInitialTextSize%';
  document.body.style.webkitTextSizeAdjust = '$kInitialTextSize%';
  document.body.style.fontSize = '$kInitialTextSize%';
});
""";

  late UserScript textSizeUserScript = UserScript(
      source: kTextSizeSourceJS,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START);

  RxBool isFavoriteEditMode = false.obs;

  Future<void> setTextsize(int textSize) async {
    kInitialTextSize.value = textSize;
    kTextSizeSourceJS = """
              document.body.style.textSizeAdjust = '$textSize%';
              document.body.style.webkitTextSizeAdjust = '$textSize%';
              document.body.style.fontSize = '$textSize%';
            """;
    await Storage.setInt(KeychatGlobal.browserTextSize, textSize);
  }

  String removeHttpPrefix(String url) {
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', '');
    }
    if (url.startsWith('https://')) {
      return url.replaceFirst('https://', '');
    }
    return url;
  }

  Widget quickSectionItem(Widget icon, String title, String url,
      {required BuildContext context,
      required VoidCallback onTap,
      Key? key,
      VoidCallback? onLongPress,
      Future<void> Function(TapDownDetails e)? onSecondaryTapDown}) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 4,
        children: [
          icon,
          Text(title,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis)
        ],
      ),
    );
  }

  Future<InAppWebViewKeepAlive?> enableKeepAlive(String url) async {
    if (GetPlatform.isDesktop) {
      return null;
    }
    var host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) {
      host = url;
    }
    mobileKeepAlive[host] = InAppWebViewKeepAlive();
    await Storage.setStringList(
        StorageKeyString.mobileKeepAlive, mobileKeepAlive.keys.toList());
    return mobileKeepAlive[host]!;
  }

  Future<void> disableKeepAlive(String url) async {
    if (GetPlatform.isDesktop) {
      return;
    }
    removeKeepAlive(url);
    await Storage.setStringList(
        StorageKeyString.mobileKeepAlive, mobileKeepAlive.keys.toList());
  }

  void removeKeepAlive(String url) {
    if (GetPlatform.isDesktop) return;
    logger.d('removeKeepAlive url: $url');
    var host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) {
      host = url;
    }
    mobileKeepAlive
      ..remove(host)
      ..remove(url);
  }

  Future<void> loadKeepAlive({bool isInit = false}) async {
    if (!GetPlatform.isMobile) return;

    var hosts = Storage.getStringList(StorageKeyString.mobileKeepAlive);
    // for init
    if (isInit && hosts.isEmpty) {
      hosts = ['jumble.social'];
      await Storage.setStringList(StorageKeyString.mobileKeepAlive, hosts);
    }
    for (final item in hosts) {
      if (!mobileKeepAlive.containsKey(item)) {
        mobileKeepAlive[item] = InAppWebViewKeepAlive();
      }
    }
  }

  Future<void> checkCurrentControllerAlive() async {
    if (tabs.isEmpty || currentIndex > tabs.length) return;
    final tab = tabs[currentIndex];
    try {
      final controller = Get.find<WebviewTabController>(tag: tab.uniqueKey);
      await controller.checkWebViewControllerAlive();
    } catch (e) {
      // not found WebviewTabController
      // logger.w('error: $e');
    }
  }
}

const String defaultSearchEngine = 'searXNG';

enum BrowserEngine { google, brave, searXNG, startpage }
