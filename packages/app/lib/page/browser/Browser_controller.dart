import 'dart:convert' show jsonEncode, jsonDecode;

import 'package:app/controller/setting.controller.dart';
import 'package:app/models/browser/browser_favorite.dart';
import 'package:app/models/browser/browser_history.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/page/browser/BrowserDetailPage.dart';
import 'package:app/service/storage.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    hide Storage, WebResourceError;
import 'package:get/get.dart';

class BrowserController extends GetxController {
  late TextEditingController textController;
  RxString title = 'Loading'.obs;
  RxString input = ''.obs;
  RxDouble progress = 0.2.obs;

  RxSet<String> enableSearchEngine = <String>{}.obs;
  RxList<BrowserFavorite> favorites = <BrowserFavorite>[].obs;
  RxList<BrowserHistory> histories = <BrowserHistory>[].obs;
  RxMap<String, dynamic> config = <String, dynamic>{}.obs;
  static const maxHistoryInHome = 12;

  Function(String url)? urlChangeCallBack;

  WebViewEnvironment? webViewEnvironment;

  loadConfig() async {
    String? localConfig = await Storage.getString('browserConfig');
    if (localConfig == null) {
      localConfig = jsonEncode({
        "enableHistory": true,
        "enableBookmark": true,
        "enableRecommend": true
      });
      Storage.setString('browserConfig', localConfig);
    }
    config.value = jsonDecode(localConfig);
  }

  setConfig(String key, dynamic value) async {
    config[key] = value;
    await Storage.setString('browserConfig', jsonEncode(config));
    config.refresh();
  }

  Future addHistory(String url, String title, [String? favicon]) async {
    if (!config['enableHistory']) return;

    if (histories.isNotEmpty && histories[0].url == url) {
      DateTime now = DateTime.now();
      DateTime lastVisit = histories[0].createdAt;
      if (now.difference(lastVisit).inMinutes < 1) {
        return;
      }
    }
    BrowserHistory history =
        BrowserHistory(url: url, title: title, favicon: favicon);
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.browserHistorys.put(history);
    });
    histories.insert(0, history);
    if (histories.length > maxHistoryInHome) {
      for (int i = histories.length - 1; i > 1; i--) {
        if (histories[i].url == url) {
          histories.removeAt(i);
        }
      }
      if (histories.length > maxHistoryInHome) {
        histories.removeRange(maxHistoryInHome, histories.length);
      }
    }
  }

  addSearchEngine(String engine) async {
    enableSearchEngine.add(engine);
    Storage.setStringList('searchEngine', enableSearchEngine.toList());
  }

  initBrowser() {
    title.value = 'Loading';
    progress.value = 0.0;
  }

  lanuchWebview(
      {required String content,
      String engine = 'google',
      String? defaultTitle}) {
    if (content.isEmpty) return;
    EasyThrottle.throttle('browserOnComplete', const Duration(seconds: 2),
        () async {
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
        }
      }
      uri = Uri.tryParse(content);
      if (uri == null) return;
      if (defaultTitle != null) {
        title.value = defaultTitle;
      }
      initBrowser();
      Get.to(() => BrowserDetailPage(content, title.value));
    });
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
    List<String> searchEngine = await Storage.getStringList('searchEngine');
    if (searchEngine.isEmpty) {
      enableSearchEngine.addAll(BrowserEngine.values.map((e) => e.name));
    } else {
      enableSearchEngine.addAll(searchEngine);
    }
    loadConfig();
    loadFavorite();
    // loadHistory();
    initWebview();
    super.onInit();
  }

  initWebview() async {
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
}

enum BrowserEngine { google, brave, searXNG, startpage }
