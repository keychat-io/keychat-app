import 'dart:convert' show jsonEncode, jsonDecode;

import 'package:app/controller/home.controller.dart';
import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/models/browser/browser_history.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/identity.dart';
import 'package:app/page/browser/webview_detail_page.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum BrowserEngine { google, brave, duckduckgo }

class BrowserController extends GetxController {
  late TextEditingController textController;
  RxString title = 'Loading'.obs;
  RxString input = ''.obs;
  RxDouble progress = 0.2.obs;
  Rx<Identity> identity = Identity(name: '', npub: '', secp256k1PKHex: '').obs;
  RxSet<String> enableSearchEngine = <String>{}.obs;
  RxList<BrowserBookmark> bookmarks = <BrowserBookmark>[].obs;
  RxList<BrowserHistory> histories = <BrowserHistory>[].obs;
  late EcashController ecashController;

  RxList recommendedUrls = [
    {"title": "Iris", "url": "https://iris.to/"},
    {
      "title": "Anonymous eSIM",
      "url": "https://silent.link/#generic_price_table"
    },
    {"title": "Tetris", "url": "https://chvin.github.io/react-tetris/"},
    {"title": "KeyChat", "url": "https://www.keychat.io/"},
  ].obs;

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
    const maxHistoryInHome = 4;
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

  @override
  void onInit() async {
    ecashController = Get.find<EcashController>();
    textController = TextEditingController();
    textController.addListener(() {
      input.value = textController.text.trim();
    });
    List<Identity> identities = await IdentityService.instance.listIdentity();
    if (identities.isNotEmpty) {
      identity.value = identities.first;
    }

    // load search engine
    List<String> searchEngine = await Storage.getStringList('searchEngine');
    if (searchEngine.isEmpty) {
      enableSearchEngine.addAll(BrowserEngine.values.map((e) => e.name));
    } else {
      enableSearchEngine.addAll(searchEngine);
    }
    // loadBookmarks();
    loadHistory();
    super.onInit();
  }

  loadBookmarks() async {
    bookmarks.value = await BrowserBookmark.getAll(limit: 8);
  }

  loadHistory() async {
    histories.value = await BrowserHistory.getAll(limit: 4);
  }

  addSearchEngine(String engine) async {
    enableSearchEngine.add(engine);
    Storage.setStringList('searchEngine', enableSearchEngine.toList());
  }

  removeSearchEngine(String engine) async {
    enableSearchEngine.remove(engine);
    Storage.setStringList('searchEngine', enableSearchEngine.toList());
  }

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    String str = request.url;
    logger.d('NavigationRequest: $str');
    if (str.startsWith('cashu')) {
      ecashController.proccessCashuAString(str);
      return NavigationDecision.prevent;
    }
    // lighting invoice
    if (str.startsWith('lightning:')) {
      str = str.replaceFirst('lightning:', '');
      ecashController.proccessPayLightingBill(str, pay: true);
      return NavigationDecision.prevent;
    }
    if (str.startsWith('lnbc')) {
      ecashController.proccessPayLightingBill(str, pay: true);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  lanuchWebview(
      {required String content,
      String engine = 'google',
      String? defaultTitle}) {
    if (content.isEmpty) return;
    EasyThrottle.throttle('browserOnComplete', const Duration(seconds: 2),
        () async {
      if (content.startsWith('http') == false) {
        switch (engine) {
          case 'google':
            content = 'https://www.google.com/search?q=$content';
            break;
          case 'brave':
            content = 'https://search.brave.com/search?q=$content';
          case 'bing':
            content = 'https://www.bing.com/search?q=$content';
          case 'duckduckgo':
            content = 'https://duckduckgo.com/?q=$content';
            break;
        }
      }
      Uri? uri = Uri.tryParse(content);
      if (uri == null) return;
      if (defaultTitle != null) {
        title.value = defaultTitle;
      }
      WebViewController controller = WebViewController();
      if (GetPlatform.isDesktop) {
        controller.setUserAgent(
            "Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.6778.135 Mobile Safari/537.36");
      }
      controller.setOnConsoleMessage((message) {
        logger.d('console: ${message.message}');
      });
      controller.addJavaScriptChannel('nc',
          onMessageReceived: (JavaScriptMessage message) {
        logger.d('Received message from javascript: ${message.message}');
        Map<String, dynamic> data = jsonDecode(message.message);
        if (data['action'] == 'getPublicKey') {
          String publicKey = 'YOUR_PUBLIC_KEY';
          Map<String, dynamic> response = {
            'messageId': data['messageId'],
            'success': true,
            'result': publicKey
          };
          logger.d(response);
          controller
              .runJavaScript('window.postMessage(${jsonEncode(response)},"*")');
        }
      });
      onPageFinished(String url) async {
        String? res = await controller.getTitle();
        logger.d('Page finished loading: $url');
        if (res != null) {
          title.value = res;
          await addHistory(url, title.value);
        }
        progress.value = 0.0;

        var identity = Get.find<HomeController>().getSelectedIdentity();
        String pubkey = identity.secp256k1PKHex;
        controller.runJavaScript('''
if (typeof window.nostr === 'undefined') {
  window.nostr = {};
}
window.nostr.getPublicKey = function () {
  return '$pubkey';
};
window.nostr.signEvent = async function (event) {
  let res = await window.nostr.sendMessage({action: 'signEvent', event: event});
  return res;
};

function generateUniqueId() {
  return Math.random().toString(36).substring(2, 15);
}

window.nc.sendMessage = function (message) {
  return new Promise((resolve, reject) => {
    const messageId = generateUniqueId();
    window.addEventListener('message', function handler(e) {
      console.log('receive from dart:', JSON.stringify(e.data));
      if (e.data && e.data.messageId === messageId) {
        window.removeEventListener('message', handler);
        if (e.data.success) {
          resolve(e.data.result);
        } else {
          reject(e.data.error);
        }
      }
    });
    window.nc.postMessage(JSON.stringify({ ...message, messageId: messageId }));
  });
};       
''');
      }

      onProgress(int data) {
        progress.value = data / 100;
      }

      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
            onProgress: onProgress,
            onUrlChange: (UrlChange urlChange) async {
              // not proccess the first url
              if (title.value == 'Loading') {
                return;
              }
              String? url = urlChange.url;
              if (url == null) return;
              logger.d('urlChange: $url');
              if (urlChangeCallBack != null) {
                urlChangeCallBack!(url);
              }
              String? newTitle = await controller.getTitle();
              if (newTitle != null) {
                title.value = newTitle;
              }
              addHistory(urlChange.url!, title.value);
            },
            onPageStarted: (String url) {
              logger.d('Page started loading: $url');
            },
            onPageFinished: onPageFinished,
            onHttpError: (HttpResponseError error) {
              logger.d('HTTP error: $error');
            },
            onWebResourceError: (WebResourceError error) {
              logger.d('Web Resource error: $error');
            },
            onNavigationRequest: _onNavigationRequest))
        ..loadRequest(uri);
      // fix ios Canpop issue
      Navigator.of(Get.context!).push(
        MaterialPageRoute(
          builder: (context) => WebviewDetailPage(controller),
        ),
      );
      initBrowser();
    });
  }

  initBrowser() {
    title.value = 'Loading';
    progress.value = 0.0;
  }

  Function(String url)? urlChangeCallBack;

  setUrlChangeCallBack(Function(String url) callBack) {
    urlChangeCallBack = callBack;
  }
}
