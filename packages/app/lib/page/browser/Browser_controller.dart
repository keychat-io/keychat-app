import 'dart:convert' show jsonEncode, jsonDecode;

import 'package:app/controller/home.controller.dart';
import 'package:app/models/identity.dart';
import 'package:app/page/browser/webview_detail_page.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/storage.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum BrowserEngine { google, brave, duckduckgo }

class BrowserController extends GetxController {
  late TextEditingController textController;
  RxString title = 'Loading'.obs;
  RxString input = ''.obs;
  RxDouble progress = 0.2.obs;
  Rx<Identity> identity = Identity(name: '', npub: '', secp256k1PKHex: '').obs;
  RxSet<String> enableSearchEngine = <String>{}.obs;

  RxList recommendedUrls = [
    {
      "title": "Anonymous eSIM",
      "url": "https://silent.link/#generic_price_table"
    },
    {"title": "Tetris", "url": "https://chvin.github.io/react-tetris/"},
    {"title": "Primal", "url": "https://primal.net/"},
    {"title": "KeyChat", "url": "https://www.keychat.io/"},
  ].obs;
  RxList<Map<String, String>> historyUrls = <Map<String, String>>[].obs;

  void addUrlToHistory(String url, String title) {
    historyUrls.removeWhere((element) => element['url'] == url);
    historyUrls.insert(0, {'url': url, 'title': title});
    if (historyUrls.length > 10) {
      historyUrls.removeLast();
    }
    _saveHistoryToLocalStorage();
  }

  void _saveHistoryToLocalStorage() async {
    List<String> historyList = historyUrls.map((e) => jsonEncode(e)).toList();
    await Storage.setStringList('browserHistory', historyList);
  }

  void _loadHistoryFromLocalStorage() async {
    List<String>? storedHistory = await Storage.getStringList('browserHistory');
    var data = storedHistory
        .map((e) => Map<String, String>.from(jsonDecode(e)))
        .toList();
    historyUrls.value = data;
  }

  @override
  void onInit() async {
    textController = TextEditingController();
    textController.addListener(() {
      input.value = textController.text.trim();
    });
    List<Identity> identities = await IdentityService.instance.listIdentity();
    if (identities.isNotEmpty) {
      identity.value = identities.first;
    }
    _loadHistoryFromLocalStorage();

    // load search engine
    List<String> searchEngine = await Storage.getStringList('searchEngine');
    if (searchEngine.isEmpty) {
      enableSearchEngine.addAll(BrowserEngine.values.map((e) => e.name));
    } else {
      enableSearchEngine.addAll(searchEngine);
    }

    super.onInit();
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
    EcashController ecashController = Get.find<EcashController>();

    if (str.startsWith('cashu')) {
      ecashController.proccessCashuAString(str);
      return NavigationDecision.prevent;
    }
    // lighting invoice
    if (str.startsWith('lightning:')) {
      str = str.replaceFirst('lightning:', '');
      ecashController.proccessPayLightingBill(str);
      return NavigationDecision.prevent;
    }
    if (str.startsWith('lnbc')) {
      ecashController.proccessPayLightingBill(str);
      return NavigationDecision.prevent;
    }

    if (!str.startsWith('http')) {
      launchUrl(Uri.parse(str), mode: LaunchMode.externalNonBrowserApplication);
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
      addUrlToHistory(content, title.value);
      WebViewController controller = WebViewController();
      if (GetPlatform.isDesktop) {
        controller.setUserAgent(
            "Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.6778.135 Mobile Safari/537.36");
      }
      controller.addJavaScriptChannel('nc',
          onMessageReceived: (JavaScriptMessage message) {
        print('Received message from javascript: ${message.message}');
        Map<String, dynamic> data = jsonDecode(message.message);
        if (data['action'] == 'getPublicKey') {
          String publicKey = 'YOUR_PUBLIC_KEY';
          Map<String, dynamic> response = {
            'messageId': data['messageId'],
            'success': true,
            'result': publicKey
          };
          print(response);
          controller
              .runJavaScript('window.postMessage(${jsonEncode(response)},"*")');
        }
      });
      onPageFinished(String url) async {
        String? res = await controller.getTitle();
        if (res != null) {
          title.value = res;
          addUrlToHistory(url, title.value);
        }
        print('Page finished loading: $url');
        progress.value = 0.0;

        //
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
  let event = await window.nostr.sendMessage({action: 'signEvent', event: event});
  return event;
};

function generateUniqueId() {
  return Math.random().toString(36).substring(2, 15);
}

window.nc.sendMessage = function (message) {
  return new Promise((resolve, reject) => {
    const messageId = generateUniqueId();
    window.addEventListener('message', function handler(event) {
      console.log('receive from dart:', JSON.stringify(event.data));
      if (event.data && event.data.messageId === messageId) {
        window.removeEventListener('message', handler);
        if (event.data.success) {
          resolve(event.data.result);
        } else {
          reject(event.data.error);
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
            onPageStarted: (String url) {
              print('Page started loading: $url');
            },
            onPageFinished: onPageFinished,
            onHttpError: (HttpResponseError error) {
              print('HTTP error: $error');
            },
            onWebResourceError: (WebResourceError error) {
              print('Web Resource error: $error');
            },
            onNavigationRequest: _onNavigationRequest))
        ..loadRequest(uri);

      await Get.to(() => WebviewDetailPage(controller));
      title.value = 'Loading';
    });
  }

  void clearHistory() {
    historyUrls.clear();
    if (historyUrls.isEmpty) {
      Storage.removeString('browserHistory');
      return;
    }
  }
}
