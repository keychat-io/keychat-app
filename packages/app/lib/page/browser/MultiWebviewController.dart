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
import 'package:isar/isar.dart';
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
        return;
      }
    }
    if (removeIndex <= currentIndex) {
      setCurrentTabIndex(currentIndex - 1);
    } else {
      setCurrentTabIndex(currentIndex);
    }
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
      {required String content,
      String engine = 'google',
      String? defaultTitle}) async {
    if (content.isEmpty) return;

    if (GetPlatform.isLinux) {
      logger.i('webview not working on linux');
      if (!await launchUrl(Uri.parse(content))) {
        throw Exception('Could not launch $content');
      }
      return;
    }
    String uniqueKey = generate64RandomHexChars(8);
    Uri? uri;
    if (content.startsWith('http') == false) {
      // try: domain.com
      bool isDomain = Utils.isDomain(content);
      // start search engine
      if (isDomain) {
        content = 'https://$content';
      } else {
        engine = engine.toLowerCase();
        switch (engine) {
          case 'google':
            content = 'https://www.google.com/search?q=$content';
            break;
          case 'brave':
            content = 'https://search.brave.com/search?q=$content';
          case 'startpage':
            content = 'https://www.startpage.com/sp/search?q=$content';
          case 'searxng':
            content = 'https://searx.tiekoetter.com/search?q=$content';
            break;
        }
        if (GetPlatform.isMobile) {
          String? host = Uri.tryParse(content)?.host;
          if (host != null) {
            mobileKeepAlive.remove(host); // remove keep alive
          }
        }
      }
    }
    uri = Uri.tryParse(content);
    if (uri == null) return;
    if (GetPlatform.isMobile) {
      uniqueKey = uri.host;
      Get.to(
          () => WebviewTab(
                initUrl: content,
                initTitle: title.value,
                uniqueKey: uniqueKey, // for close controller
                windowId: 0,
                isCache: mobileKeepAlive.containsKey(uniqueKey),
                keepAlive: _getKeepAliveObject(uniqueKey),
              ),
          transition: Transition.cupertino);
      return;
    }

    final tab = WebviewTab(
      uniqueKey: uniqueKey,
      initUrl: content,
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
  }

  InAppWebViewKeepAlive? _getKeepAliveObject(String uniqueKey) {
    if (!GetPlatform.isMobile) return null;

    if (!mobileKeepAlive.containsKey(uniqueKey)) {
      mobileKeepAlive[uniqueKey] = InAppWebViewKeepAlive();
    }
    return mobileKeepAlive[uniqueKey];
  }

  void removeKeepAliveObject(String uniqueKey) {
    mobileKeepAlive.remove(uniqueKey);
  }

  InAppWebViewKeepAlive addKeepAliveObject(String uniqueKey) {
    mobileKeepAlive[uniqueKey] = InAppWebViewKeepAlive();
    return mobileKeepAlive[uniqueKey]!;
  }

  setCurrentTabIndex(index) {
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
    String? localConfig = await Storage.getString(KeychatGlobal.browserConfig);
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
    int? textSize = await Storage.getInt(KeychatGlobal.browserTextSize);
    if (textSize != null) {
      kInitialTextSize.value = textSize;
    }
  }

  setConfig(String key, dynamic value) async {
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

  addSearchEngine(String engine) async {
    enableSearchEngine.add(engine);
    Storage.setStringList('searchEngine', enableSearchEngine.toList());
  }

  initBrowser() {
    title.value = 'Loading';
    progress.value = 0.0;
  }

  loadFavorite() async {
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
        (await Storage.getString('defaultSearchEngine') ?? defaultSearchEngine);

    await loadConfig();
    loadFavorite();
    initWebview();
    deleteOldHistories();

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

  removeSearchEngine(String engine) async {
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
}

const String defaultSearchEngine = 'searXNG';

enum BrowserEngine { google, brave, searXNG, startpage }
