import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/models/browser/browser_history.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/identity.dart';
import 'package:app/page/browser/BrowserDetailPage.dart';
import 'package:app/service/identity.service.dart';
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
  Rx<Identity> identity =
      Identity(name: '', npub: '', secp256k1PKHex: '001').obs;
  RxSet<String> enableSearchEngine = <String>{}.obs;
  RxList<BrowserBookmark> bookmarks = <BrowserBookmark>[].obs;
  RxList<BrowserHistory> histories = <BrowserHistory>[].obs;
  static const maxHistoryInHome = 2;

  Function(String url)? urlChangeCallBack;

  Future addHistory(String url, String title) async {
    if (histories.isNotEmpty && histories[0].url == url) {
      DateTime now = DateTime.now();
      DateTime lastVisit = histories[0].createdAt;
      if (now.difference(lastVisit).inMinutes < 1) {
        return;
      }
    }
    BrowserHistory history = BrowserHistory(url: url, title: title);
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

  loadBookmarks() async {
    bookmarks.value = await BrowserBookmark.getAll(limit: 2);
  }

  loadHistory() async {
    histories.value = await BrowserHistory.getAll(limit: maxHistoryInHome);
  }

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }

  @override
  void onInit() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
    }

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
    loadDefaultIdentity();
    loadBookmarks();
    loadHistory();
    super.onInit();
  }

  removeSearchEngine(String engine) async {
    enableSearchEngine.remove(engine);
    Storage.setStringList('searchEngine', enableSearchEngine.toList());
  }

  Future loadDefaultIdentity() async {
    String? pubkey = await Storage.getString('browser_identity');
    if (pubkey != null) {
      var model =
          await IdentityService.instance.getIdentityByNostrPubkey(pubkey);
      if (model != null) {
        identity.value = model;
        return;
      }
    }
    // set default
    List<Identity> identities = await IdentityService.instance.listIdentity();
    if (identities.isNotEmpty) {
      identity.value = identities.first;
    }
  }

  Future setDefaultIdentity(Identity identity) async {
    await Storage.setString('browser_identity', identity.secp256k1PKHex);
    loadDefaultIdentity();
  }
}

enum BrowserEngine { google, brave, searXNG, startpage }
