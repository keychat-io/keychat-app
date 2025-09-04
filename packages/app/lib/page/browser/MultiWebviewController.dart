import 'dart:convert' show jsonEncode, jsonDecode;

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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    hide Storage, WebResourceError;
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:url_launcher/url_launcher.dart';

class WebviewTabData {
  WebviewTab tab;
  String uniqueKey;
  String? title;
  String url;
  String? favicon;
  WebviewTabData(
      {required this.tab, required this.uniqueKey, required this.url});
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

  late Function(String url) urlChangeCallBack;

  WebViewEnvironment? webViewEnvironment;

  void addNewTab() {
    String uniqueId = generate64RandomHexChars(8);

    // use new tab if exist
    if (GetPlatform.isMobile) {
      for (var i = 0; i < tabs.length; i++) {
        var item = tabs[i];
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
    String uniqueId = generate64RandomHexChars(8);
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
    int removeIndex = -1;
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].uniqueKey == tabId) {
        removeIndex = i;
        break;
      }
    }
    removeByIndex(removeIndex);
  }

  Future launchWebview(
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
    String uniqueKey = generate64RandomHexChars(8);
    Uri? uri;
    if (initUrl.startsWith('http') == false) {
      // try: domain.com
      bool isDomain = Utils.isDomain(initUrl);
      // start search engine
      if (isDomain) {
        initUrl = 'https://$initUrl';
      } else {
        engine = engine.toLowerCase();
        switch (engine) {
          case 'google':
            initUrl = 'https://www.google.com/search?q=$initUrl';
            break;
          case 'brave':
            initUrl = 'https://search.brave.com/search?q=$initUrl';
          case 'startpage':
            initUrl = 'https://www.startpage.com/sp/search?q=$initUrl';
          case 'searxng':
            initUrl = 'https://searx.tiekoetter.com/search?q=$initUrl';
            break;
        }
        if (GetPlatform.isMobile) {
          await refreshKeepAliveObject(initUrl);
        }
      }
    }
    uri = Uri.tryParse(initUrl);
    if (uri == null) return;
    if (GetPlatform.isMobile) {
      uniqueKey = uri.host;
      Get.to(
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
      tabs.removeAt(currentIndex);
      tabs.insert(currentIndex,
          WebviewTabData(tab: tab, uniqueKey: uniqueKey, url: tab.initUrl));
      setCurrentTabIndex(currentIndex);

      saveDesktopTabs();
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

    saveDesktopTabs();
  }

  void setCurrentTabIndex(int index) {
    if (index < 0 || index >= tabs.length) {
      index = 0;
    }
    currentIndex = index;
    updatePageTabIndex(index);
  }

  Function(int) updatePageTabIndex = (index) {};

  int getLastWindowId() {
    int windowId = 0;
    for (var item in tabs) {
      if (item.tab.windowId > windowId) {
        windowId = item.tab.windowId + 1;
      }
    }
    return windowId;
  }

  Future loadConfig() async {
    String? localConfig = Storage.getString(KeychatGlobal.browserConfig);
    if (localConfig == null) {
      localConfig = jsonEncode({
        "enableHistory": true,
        "enableBookmark": true,
        "enableRecommend": true,
        "historyRetentionDays": 30,
        "autoSignEvent": true,
      });
      Storage.setString('browserConfig', localConfig);
    }
    config.value = jsonDecode(localConfig);

    // text zoom
    int? textSize = Storage.getInt(KeychatGlobal.browserTextSize);
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
  Future addHistory(String url, String title, [String? favicon]) async {
    if (!config['enableHistory']) return;

    if (lastHistory != null) {
      if (lastHistory!.url == url) {
        DateTime now = DateTime.now();
        DateTime lastVisit = lastHistory!.createdAt;
        if (now.difference(lastVisit).inMinutes < 1) {
          return;
        }
      }
    }
    BrowserHistory history =
        BrowserHistory(url: url, title: title, favicon: favicon);
    lastHistory = history;
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserHistorys.put(history);
    });
  }

  Future<void> addSearchEngine(String engine) async {
    enableSearchEngine.add(engine);
    Storage.setStringList('searchEngine', enableSearchEngine.toList());
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
  void onInit() async {
    textController = TextEditingController();
    textController.addListener(() {
      input.value = textController.text.trim();
    });

    // load search engine
    defaultSearchEngineObx.value =
        (Storage.getString('defaultSearchEngine') ?? defaultSearchEngine);

    await loadConfig();
    await loadKeepAlive();
    loadFavorite();
    initWebview();
    deleteOldHistories();
    await loadDesktopTabs();
    if (tabs.isEmpty && GetPlatform.isDesktop) {
      addNewTab();
    }
    super.onInit();
  }

  Future<void> deleteOldHistories() async {
    if (!config['enableHistory']) return;

    int retentionDays = config['historyRetentionDays'] ?? 30;
    DateTime thresholdDate =
        DateTime.now().subtract(Duration(days: retentionDays));

    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserHistorys
          .filter()
          .createdAtLessThan(thresholdDate)
          .deleteAll();
    });
  }

  Future initWebview() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final availableVersion = await WebViewEnvironment.getAvailableVersion();
      assert(availableVersion != null,
          'Failed to find an installed WebView2 Runtime or non-stable Microsoft Edge installation.');
      String browserCacheFolder =
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
    Storage.setStringList('searchEngine', enableSearchEngine.toList());
  }

  Map<String, String> cachedFavicon = {};
  Future<String?> getFavicon(
      InAppWebViewController controller, String host) async {
    if (cachedFavicon.containsKey(host)) {
      return cachedFavicon[host];
    }
    try {
      List<Favicon> favicons = await controller.getFavicons().timeout(
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

    List<Map<String, dynamic>> tabData = tabs
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

  Future<void> loadDesktopTabs() async {
    if (!GetPlatform.isDesktop) return;

    try {
      String? savedTabs =
          Storage.getString(StorageKeyString.desktopBrowserTabs);
      if (savedTabs == null || savedTabs.isEmpty) return;

      List<dynamic> tabData = jsonDecode(savedTabs);
      logger.d('Loading ${tabData.length} desktop tabs');

      for (var data in tabData) {
        String url = data['url'] ?? '';
        String title = data['title'] ?? '';
        String? favicon = data['favicon'];

        if (url.isNotEmpty && url != KeychatGlobal.newTab) {
          String uniqueId = generate64RandomHexChars(8);
          final tab = WebviewTab(
            uniqueKey: uniqueId,
            initUrl: url,
            key: GlobalObjectKey(uniqueId),
            windowId: getLastWindowId(),
          );

          WebviewTabData tabData = WebviewTabData(
            tab: tab,
            uniqueKey: uniqueId,
            url: url,
          );
          tabData.title = title.isNotEmpty ? title : null;
          tabData.favicon = favicon;

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
      String? title,
      required String url,
      String? favicon}) {
    int tabIndex = tabs.indexWhere((tab) => tab.uniqueKey == uniqueId);
    if (tabIndex >= 0) {
      if (title != null) {
        tabs[tabIndex].title = title;
      }
      tabs[tabIndex].url = url;
      if (favicon != null) {
        tabs[tabIndex].favicon = favicon;
      }
      tabs.refresh(); // Trigger UI update since we're using GetX

      saveDesktopTabs();
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
    // for mobile
    try {
      var controller = Get.find<WebviewTabController>(tag: uniqueKey);
      logger.i('found controller $uniqueKey');
      return controller;
    } catch (e) {
      // permanent. manaully to delete
      return Get.put(WebviewTabController(uniqueKey, initUrl, initTitle),
          tag: uniqueKey);
    }
  }

  void setTabDataFavicon({required String uniqueId, required String favicon}) {
    int tabIndex = tabs.indexWhere((tab) => tab.uniqueKey == uniqueId);
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

  Future setTextsize(int textSize) async {
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
      Future Function(TapDownDetails e)? onSecondaryTapDown}) {
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
    String? host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) {
      host = url;
    }
    logger.d('enableKeepAlive host: $host');
    mobileKeepAlive[host] = InAppWebViewKeepAlive();
    await Storage.setStringList(
        StorageKeyString.mobileKeepAlive, mobileKeepAlive.keys.toList());
    return mobileKeepAlive[host]!;
  }

  Future<InAppWebViewKeepAlive?> refreshKeepAliveObject(String url) async {
    if (GetPlatform.isDesktop) {
      return null;
    }
    String? host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) {
      host = url;
    }
    mobileKeepAlive[host] = InAppWebViewKeepAlive();
    return mobileKeepAlive[host]!;
  }

  Future disableKeepAlive(String url) async {
    if (GetPlatform.isDesktop) {
      return null;
    }
    removeKeepAlive(url);
    await Storage.setStringList(
        StorageKeyString.mobileKeepAlive, mobileKeepAlive.keys.toList());
  }

  Null removeKeepAlive(String url) {
    if (GetPlatform.isDesktop) {
      return null;
    }
    logger.d('removeKeepAlive url: $url');
    String? host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) {
      host = url;
    }
    mobileKeepAlive.remove(host);
    mobileKeepAlive.remove(url);
  }

  // Add this method to get current KeepAlive hosts count
  int getKeepAliveHostsCount() {
    return mobileKeepAlive.length;
  }

  // Add this method to get all KeepAlive hosts
  List<String> getKeepAliveHosts() {
    return mobileKeepAlive.keys.toList();
  }

  Future<void> loadKeepAlive() async {
    if (!GetPlatform.isMobile) return;

    List<String> hosts =
        Storage.getStringList(StorageKeyString.mobileKeepAlive);
    // for init
    if (hosts.isEmpty) {
      hosts = ['jumble.social'];
      await Storage.setStringList(StorageKeyString.mobileKeepAlive, hosts);
    }
    for (var item in hosts) {
      if (!mobileKeepAlive.containsKey(item)) {
        mobileKeepAlive[item] = InAppWebViewKeepAlive();
      }
    }
  }
}

const String defaultSearchEngine = 'searXNG';

enum BrowserEngine { google, brave, searXNG, startpage }
