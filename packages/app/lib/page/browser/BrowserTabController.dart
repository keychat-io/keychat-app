import 'package:app/app.dart';
import 'package:app/controller/setting.controller.dart';
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
  late InAppWebViewSettings settings;

  @override
  void onClose() {
    webViewController?.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    SettingController sc = Get.find<SettingController>();
    settings = InAppWebViewSettings(
        appCachePath: sc.browserCacheFolder,
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
        supportMultipleWindows: GetPlatform.isDesktop,
        transparentBackground: Get.isDarkMode,
        cacheEnabled: true,
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

  void setBrowserConnect(BrowserConnect? value) {
    if (value == null) {
      browserConnect.value = BrowserConnect(host: '', pubkey: '');
    } else {
      browserConnect.value = value;
    }
  }
}
