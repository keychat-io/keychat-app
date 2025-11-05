import 'dart:math' show Random;

import 'package:keychat/app.dart';
import 'package:keychat/page/browser/MultiWebviewController.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart' show PageStorageKey;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

class WebviewTabController extends GetxController {
  WebviewTabController(String key, String initUrl, String? initTitle) {
    uniqueKey = key;
    url = initUrl;
    final domain = Uri.parse(initUrl).host;
    pageStorageKey.value = PageStorageKey<String>(domain);
    if (initTitle != null && initTitle.isNotEmpty) {
      title.value = initTitle;
    }
    multiWebviewController = Get.find<MultiWebviewController>();
  }
  Rx<BrowserConnect> browserConnect = BrowserConnect(host: '', pubkey: '').obs;
  RxBool canGoBack = false.obs;
  RxBool canGoForward = false.obs;
  InAppWebViewController? inAppWebViewController;
  RxString title = ''.obs;
  String url = '';
  RxDouble progress = 0.1.obs;
  String? favicon;
  Rx<PageStorageKey<String>> pageStorageKey = const PageStorageKey('').obs;
  late MultiWebviewController multiWebviewController;
  late String uniqueKey;

  late InAppWebViewSettings settings;

  @override
  void onClose() {
    if (title.value == url) {
      multiWebviewController.removeKeepAlive(url);
    }
    inAppWebViewController?.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    settings = InAppWebViewSettings(
      allowUniversalAccessFromFileURLs: true,
      isInspectable: kDebugMode,
      allowsInlineMediaPlayback: true,
      useShouldOverrideUrlLoading: true,
      disableDefaultErrorPage: true,
      useOnDownloadStart: true,
      transparentBackground: true,
      supportMultipleWindows: GetPlatform.isDesktop,
      textZoom: multiWebviewController.kInitialTextSize.value,
      appCachePath: Utils.browserCacheFolder,
      iframeAllow: 'camera; microphone',
      algorithmicDarkeningAllowed: true,
      iframeAllowFullscreen: true,
    );

    super.onInit();
  }

  Future<void> updateTextSize(int textSize) async {
    await multiWebviewController.setTextsize(textSize);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings.textZoom = textSize;
      await inAppWebViewController?.setSettings(settings: settings);
    } else {
      // update current text size
      logger.i(
        'updateTextSize: $textSize, ${multiWebviewController.kTextSizeSourceJS}',
      );
      await inAppWebViewController?.evaluateJavascript(
        source: multiWebviewController.kTextSizeSourceJS,
      );

      // update the User Script for the next page load
      await inAppWebViewController?.removeUserScript(
        userScript: multiWebviewController.textSizeUserScript,
      );
      multiWebviewController.textSizeUserScript = UserScript(
        source:
            """
window.addEventListener('DOMContentLoaded', function(event) {
  document.body.style.textSizeAdjust = '$textSize%';
  document.body.style.webkitTextSizeAdjust = '$textSize%';
  document.body.style.fontSize = '$textSize%';
});
""",
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      );
      await inAppWebViewController?.addUserScript(
        userScript: multiWebviewController.textSizeUserScript,
      );
    }
  }

  void setWebViewController(InAppWebViewController controller, String initUrl) {
    inAppWebViewController = controller;
    if (GetPlatform.isDesktop) return;
    // Init data for keep alive on mobile
    controller.getTitle().then((value) {
      if (value != null) {
        title.value = value;
      }
    });

    controller.canGoBack().then((value) {
      canGoBack.value = value;
    });

    controller.canGoForward().then((value) {
      canGoForward.value = value;
    });
  }

  void setBrowserConnect(BrowserConnect? value) {
    if (value == null) {
      browserConnect.value = BrowserConnect(host: '', pubkey: '');
    } else {
      browserConnect.value = value;
    }
  }

  Future<void> checkWebViewControllerAlive() async {
    if (inAppWebViewController == null) return;
    EasyThrottle.throttle(
      'checkWebViewControllerAlive:$url',
      const Duration(seconds: 1),
      () async {
        try {
          await inAppWebViewController!.getUrl().timeout(
            const Duration(seconds: 2),
          );
        } catch (e) {
          logger.e('tabController dispose: $url');
          // ⛔ A MacOSInAppWebViewController was used after being disposed.
          // ⛔ Once the MacOSInAppWebViewController has been disposed, it can no longer be used.
          pageStorageKey.value = PageStorageKey<String>(
            Random().nextInt(1 << 32).toString(),
          );
        }
      },
    );
  }
}
