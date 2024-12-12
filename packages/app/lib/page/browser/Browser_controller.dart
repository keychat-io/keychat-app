import 'package:app/controller/home.controller.dart';
import 'package:app/page/browser/webview_detail_page.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BrowserController extends GetxController {
  late TextEditingController textController;
  RxString title = 'Loading'.obs;
  RxDouble progress = 0.2.obs;
  @override
  void onInit() {
    textController = TextEditingController(text: 'https://primal.net/');

    super.onInit();
  }

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }

  onComplete() {
    String text = textController.text.trim();

    if (text.isEmpty) return;
    EasyThrottle.throttle('browserOnComplete', const Duration(seconds: 2),
        () async {
      Uri? uri = Uri.tryParse(text);
      if (uri == null) return;
      if (!(text.startsWith('http://') || text.startsWith('https://'))) return;
      WebViewController controller = WebViewController()
        ..addJavaScriptChannel('nc',
            onMessageReceived: (JavaScriptMessage message) {
          print('Received message from javascript: ${message.message}');
        });
      onPageFinished(String url) async {
        String? res = await controller.getTitle();
        if (res != null) {
          title.value = res;
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
          window.nostr.getPublicKey = function() {
            return '$pubkey';
          };
          window.nostr.getPublicKey();
          window.nc.postMessage('aa','bbb','ccc');
          window.nc.postMessage(window.nostr.getPublicKey());
        ''');
      }

      onProgress(int data) {
        progress.value = data / 100;
      }

      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
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
            onNavigationRequest: (NavigationRequest request) {
              if (request.url.startsWith('https://www.youtube.com/')) {
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(uri);

      await Get.to(() => WebviewDetailPage(controller));
      title.value = 'Loading';
    });
  }
}
