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
  PullToRefreshController? pullToRefreshController;
  RxString title = ''.obs;
  RxString url = ''.obs;
  RxDouble progress = 1.0.obs;
  String? favicon;
  late MultiWebviewController multiWebviewController;
  WebviewTabController(String initUrl, String? initTitle) {
    url.value = initUrl;
    title.value = initTitle ?? initUrl;
    multiWebviewController = Get.find<MultiWebviewController>();
  }

  late InAppWebViewSettings settings;

  @override
  void onClose() {
    webViewController?.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    logger.d(multiWebviewController.kInitialTextSize.value);
    settings = InAppWebViewSettings(
        isInspectable: kDebugMode,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        useShouldOverrideUrlLoading: true,
        useOnLoadResource: true,
        safeBrowsingEnabled: true,
        disableDefaultErrorPage: true,
        allowsLinkPreview: true,
        isFraudulentWebsiteWarningEnabled: true,
        useOnDownloadStart: true,
        transparentBackground: Get.isDarkMode,
        cacheEnabled: true,
        textZoom: multiWebviewController.kInitialTextSize.value,
        appCachePath: Get.find<SettingController>().browserCacheFolder,
        iframeAllow: "camera; microphone",
        algorithmicDarkeningAllowed: true,
        iframeAllowFullscreen: true);

    pullToRefreshController = kIsWeb ||
            ![TargetPlatform.iOS, TargetPlatform.android]
                .contains(defaultTargetPlatform)
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(color: KeychatGlobal.primaryColor),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(
                    urlRequest:
                        URLRequest(url: await webViewController?.getUrl()));
              }
            });
    super.onInit();
  }

  updateTextSize(int textSize) async {
    await multiWebviewController.setTextsize(textSize);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings.textZoom = textSize;
      await webViewController?.setSettings(settings: settings);
    } else {
      // update current text size
      await webViewController?.evaluateJavascript(
          source: multiWebviewController.kTextSizeSourceJS);

      // update the User Script for the next page load
      await webViewController?.removeUserScript(
          userScript: multiWebviewController.textSizeUserScript);
      multiWebviewController.textSizeUserScript = UserScript(source: """
window.addEventListener('DOMContentLoaded', function(event) {
  document.body.style.textSizeAdjust = '$textSize%';
  document.body.style.webkitTextSizeAdjust = '$textSize%';
});
""", injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START);
      await webViewController?.addUserScript(
          userScript: multiWebviewController.textSizeUserScript);
    }
  }

  setWebViewController(InAppWebViewController controller, String initUrl) {
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
