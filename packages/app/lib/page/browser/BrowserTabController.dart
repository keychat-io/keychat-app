import 'package:app/app.dart';
import 'package:app/controller/setting.controller.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

class WebviewTabController extends GetxController {
  Rx<BrowserConnect> browserConnect = BrowserConnect(host: '', pubkey: '').obs;
  RxBool canGoBack = false.obs;
  RxBool canGoForward = false.obs;
  InAppWebViewController? webViewController;
  RxString title = ''.obs;
  RxString url = ''.obs;
  RxDouble progress = 0.1.obs;
  String? favicon;
  late MultiWebviewController multiWebviewController;
  late String uniqueKey;
  WebviewTabController(String key, String initUrl, String? initTitle) {
    uniqueKey = key;
    url.value = initUrl;
    if (initTitle != null && initTitle.isNotEmpty) {
      title.value = initTitle;
    }
    multiWebviewController = Get.find<MultiWebviewController>();
  }

  late InAppWebViewSettings settings;

  @override
  void onClose() {
    if (title.value == url.value) {
      multiWebviewController.removeKeepAlive(url.value);
    }
    webViewController?.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    settings = InAppWebViewSettings(
        cacheMode: CacheMode.LOAD_DEFAULT,
        domStorageEnabled: true,
        databaseEnabled: true,
        javaScriptEnabled: true,
        allowFileAccess: true,
        allowUniversalAccessFromFileURLs: true,
        isInspectable: kDebugMode,
        allowsInlineMediaPlayback: true,
        useShouldOverrideUrlLoading: true,
        disableDefaultErrorPage: true,
        useOnDownloadStart: true,
        transparentBackground: true,
        supportMultipleWindows: GetPlatform.isDesktop,
        cacheEnabled: true,
        textZoom: multiWebviewController.kInitialTextSize.value,
        appCachePath: Get.find<SettingController>().browserCacheFolder,
        iframeAllow: "camera; microphone",
        algorithmicDarkeningAllowed: true,
        iframeAllowFullscreen: true);

    super.onInit();
  }

  Future updateTextSize(int textSize) async {
    await multiWebviewController.setTextsize(textSize);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings.textZoom = textSize;
      await webViewController?.setSettings(settings: settings);
    } else {
      // update current text size
      logger.i(
          'updateTextSize: $textSize, ${multiWebviewController.kTextSizeSourceJS}');
      await webViewController?.evaluateJavascript(
          source: multiWebviewController.kTextSizeSourceJS);

      // update the User Script for the next page load
      await webViewController?.removeUserScript(
          userScript: multiWebviewController.textSizeUserScript);
      multiWebviewController.textSizeUserScript = UserScript(source: """
window.addEventListener('DOMContentLoaded', function(event) {
  document.body.style.textSizeAdjust = '$textSize%';
  document.body.style.webkitTextSizeAdjust = '$textSize%';
  document.body.style.fontSize = '$textSize%';
});
""", injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START);
      await webViewController?.addUserScript(
          userScript: multiWebviewController.textSizeUserScript);
    }
  }

  void setWebViewController(InAppWebViewController controller, String initUrl) {
    webViewController = controller;
    if (GetPlatform.isDesktop) return;
    // Init data for keep alive on mobile
    controller.getTitle().then((value) {
      if (value != null) {
        title.value = value;
      }
    });

    controller.getUrl().then((value) {
      if (value != null) {
        url.value = value.toString();
        Uri? current = Uri.tryParse(url.value);
        Uri? init = Uri.tryParse(initUrl);
        if (init != null && current != null) {
          if (init.path != '/' && init.path != current.path) {
            controller.loadUrl(
              urlRequest: URLRequest(url: WebUri.uri(init)),
            );
          }
        }
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
}
