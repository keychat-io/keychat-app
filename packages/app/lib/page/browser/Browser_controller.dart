import 'package:app/models/browser/browser_connect.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

class BrowserController extends GetxController {
  RxString title = 'Loading'.obs;
  RxString url = ''.obs;
  RxDouble progress = 0.2.obs;
  Rx<BrowserConnect> browserConnect = BrowserConnect(host: '', pubkey: '').obs;
  RxBool canGoBack = false.obs;
  RxBool canGoForward = false.obs;

  InAppWebViewSettings settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      useShouldOverrideUrlLoading: true,
      supportMultipleWindows: true,
      transparentBackground: Get.isDarkMode,
      cacheEnabled: true,
      iframeAllow: "camera; microphone",
      algorithmicDarkeningAllowed: true,
      iframeAllowFullscreen: true);

  initBrowser() {
    title.value = 'Loading';
    progress.value = 0.0;
  }

  void setBrowserConnect(BrowserConnect? value) {
    if (value == null) {
      browserConnect.value = BrowserConnect(host: '', pubkey: '');
    } else {
      browserConnect.value = value;
    }
  }
}
