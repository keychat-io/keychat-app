import 'dart:collection' show UnmodifiableListView;
import 'dart:convert' show jsonDecode;

import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/browser/BookmarkEdit.dart';
import 'package:app/page/browser/BrowserNewTab.dart';
import 'package:app/page/browser/BrowserTabController.dart';
import 'package:app/page/browser/FavoriteEdit.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/page/browser/SelectIdentityForBrowser.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/service/SignerService.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/utils.dart';
import 'package:auto_size_text_plus/auto_size_text_plus.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_ecash/CreateInvoice/CreateInvoice_page.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

enum WebviewTabState { start, success, failed, error }

class WebviewTab extends StatefulWidget {
  final String uniqueKey;
  final String initUrl;
  final String? initTitle;
  final int windowId;
  final InAppWebViewKeepAlive? keepAlive;
  final bool? isCache;
  const WebviewTab(
      {super.key,
      required this.windowId,
      required this.uniqueKey,
      required this.initUrl,
      this.isCache,
      this.initTitle,
      this.keepAlive});
  @override
  _WebviewTabState createState() => _WebviewTabState();
}

class _WebviewTabState extends State<WebviewTab> {
  late EcashController ecashController;
  late MultiWebviewController controller;
  late WebviewTabController tc;
  bool pageFailed = false;
  WebviewTabState state = WebviewTabState.start;
  InAppWebViewKeepAlive? inAppWebViewKeepAlive;
  PageStorageKey? pageStorageKey;
  late String initDomain;
  PullToRefreshController? pullToRefreshController;

  // Add scroll position tracking
  Map<String, Map<String, dynamic>> urlScrollPositions = {};
  bool needRestorePosition = false;

  @override
  void initState() {
    inAppWebViewKeepAlive = widget.keepAlive;
    controller = Get.find<MultiWebviewController>();
    tc = controller.getOrCreateController(
        widget.initUrl, widget.initTitle, widget.uniqueKey);
    ecashController = Get.find<EcashController>();
    initDomain = WebUri(widget.initUrl).host;
    pageStorageKey = PageStorageKey(initDomain);

    initBrowserConnect(WebUri(widget.initUrl));
    initPullToRefreshController();
    super.initState();
    if (widget.initUrl != KeychatGlobal.newTab) {
      Future.delayed(Duration(seconds: 1)).then((_) async {
        if (state == WebviewTabState.start) {
          InAppWebViewKeepAlive? newKa =
              await controller.refreshKeepAliveObject(widget.initUrl);
          setState(() {
            inAppWebViewKeepAlive = newKa;
            state = WebviewTabState.failed;
            pageStorageKey = null;
          });
        }
      });
    }
  }

  Future<void> menuOpened() async {
    var uri = await tc.webViewController?.getUrl();
    if (uri == null) return;
    initBrowserConnect(uri);
    controller.updateTabData(uniqueId: widget.uniqueKey, url: uri.toString());
  }

  void initBrowserConnect(WebUri uri) {
    BrowserConnect.getByHost(uri.host).then((value) {
      tc.setBrowserConnect(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initUrl == KeychatGlobal.newTab) return BrowserNewTab();

    return Obx(() => PopScope(
        canPop: !tc.canGoBack.value,
        onPopInvokedWithResult: (didPop, d) {
          if (didPop) return;
          goBackOrPop();
        },
        child: Scaffold(
          appBar: AppBar(
              titleSpacing: 0,
              leadingWidth: 16,
              toolbarHeight: GetPlatform.isDesktop ? 48 : 40,
              leading: Container(),
              centerTitle: true,
              title: GetPlatform.isDesktop
                  ? Row(spacing: 8, children: [
                      Obx(() => Row(children: [
                            IconButton(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                onPressed: goBackOrPop,
                                icon: const Icon(Icons.arrow_back)),
                            IconButton(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                onPressed: () {
                                  controller.removeTab(widget.uniqueKey);
                                },
                                icon: const Icon(Icons.close)),
                            IconButton(
                                onPressed: tc.canGoForward.value
                                    ? () {
                                        tc.webViewController?.goForward();
                                      }
                                    : null,
                                icon: const Icon(Icons.arrow_forward)),
                            IconButton(
                                onPressed: refreshPage,
                                icon: const Icon(Icons.refresh)),
                          ])),
                      Expanded(
                          child: Center(
                              child: AutoSizeText(
                                  controller.removeHttpPrefix(
                                      tc.title.value.isEmpty
                                          ? tc.url.value
                                          : tc.title.value),
                                  minFontSize: 10,
                                  stepGranularity: 2,
                                  maxFontSize: 16,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip)))
                    ])
                  : AutoSizeText(
                      controller.removeHttpPrefix(tc.title.value.isEmpty
                          ? tc.url.value
                          : tc.title.value),
                      minFontSize: 10,
                      stepGranularity: 2,
                      maxFontSize: 16,
                      maxLines: 1,
                      overflow: TextOverflow.clip),
              actions: [
                PopupMenuButton<String>(
                  onOpened: menuOpened,
                  onSelected: popupMenuSelected,
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem(
                        value: 'tools',
                        child: getPopTools(tc.url.value),
                      ),
                      PopupMenuItem(
                        value: 'refresh',
                        child: Row(spacing: 16, children: [
                          const Icon(Icons.refresh),
                          Text('Refresh',
                              style: Theme.of(context).textTheme.bodyLarge)
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'bookmark',
                        child: Row(spacing: 16, children: [
                          FutureBuilder(future: () async {
                            final url = await tc.webViewController?.getUrl();
                            if (url == null) return null;
                            return await DBProvider.database.browserBookmarks
                                .filter()
                                .urlEqualTo(url.toString())
                                .findFirst();
                          }(), builder: (context, snapshot) {
                            if (snapshot.data != null) {
                              return const Icon(
                                CupertinoIcons.bookmark_fill,
                                color: Colors.orange,
                              );
                            }
                            return const Icon(CupertinoIcons.bookmark);
                          }),
                          Text('Bookmark',
                              style: Theme.of(context).textTheme.bodyLarge)
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'favorite',
                        child: Row(spacing: 16, children: [
                          SvgPicture.asset(
                            'assets/images/app_add.svg',
                            height: 24,
                            width: 24,
                            colorFilter: ColorFilter.mode(
                                Theme.of(context)
                                    .iconTheme
                                    .color!
                                    .withAlpha(200),
                                BlendMode.srcIn),
                          ),
                          Text('Add to Favorites',
                              style: Theme.of(context).textTheme.bodyLarge)
                        ]),
                      ),
                      const PopupMenuItem(
                        height: 1,
                        value: 'divider',
                        child: Divider(),
                      ),
                      PopupMenuItem(
                        value: 'shareToRooms',
                        child: Row(spacing: 16, children: [
                          const Icon(CupertinoIcons.chat_bubble),
                          Text('Share to Room',
                              style: Theme.of(context).textTheme.bodyLarge)
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: Row(spacing: 16, children: [
                          const Icon(CupertinoIcons.share),
                          Text('Share',
                              style: Theme.of(context).textTheme.bodyLarge)
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'zoom',
                        child: Row(spacing: 16, children: [
                          const Icon(CupertinoIcons.zoom_in),
                          Text('Zoom Text',
                              style: Theme.of(context).textTheme.bodyLarge)
                        ]),
                      ),
                      if (GetPlatform.isMobile)
                        PopupMenuItem(
                          padding: EdgeInsets.only(left: 0),
                          value: 'KeepAlive',
                          child: ListTile(
                              leading: Transform.scale(
                                  scale: 0.6,
                                  child: FutureBuilder(future: (() async {
                                    await controller.loadKeepAlive();
                                  })(), builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).primaryColor,
                                      );
                                    }
                                    return Switch(
                                        value: controller.mobileKeepAlive.keys
                                            .contains(initDomain),
                                        onChanged: (value) async {
                                          if (value) {
                                            InAppWebViewKeepAlive? newKa =
                                                await controller
                                                    .enableKeepAlive(
                                                        initDomain);
                                            setState(() {
                                              inAppWebViewKeepAlive = newKa;
                                            });
                                            Get.back();
                                            EasyLoading.showSuccess(
                                                'KeepAlive Enabled. Take effect after restarting the page.');
                                            return;
                                          }
                                          await controller
                                              .disableKeepAlive(initDomain);
                                          Get.back();
                                          EasyLoading.showSuccess(
                                              'KeepAlive Disabled.');
                                        });
                                  })),
                              contentPadding: EdgeInsets.all(0),
                              horizontalTitleGap: 0,
                              title: Text('Keep Alive',
                                  style:
                                      Theme.of(context).textTheme.bodyLarge)),
                        ),
                      if (tc.browserConnect.value.host == "")
                        PopupMenuItem(
                          value: 'clear',
                          child: Row(spacing: 12, children: [
                            const Icon(Icons.storage),
                            Text('Clear Cache',
                                style: Theme.of(context).textTheme.bodyLarge)
                          ]),
                        ),
                      const PopupMenuItem(
                        height: 1,
                        value: 'divider',
                        child: Divider(),
                      ),
                      if (tc.browserConnect.value.host != "")
                        PopupMenuItem(
                          value: 'disconnect',
                          child: Row(spacing: 12, children: [
                            const Icon(Icons.logout),
                            Text('ID Logout',
                                style: Theme.of(context).textTheme.bodyLarge)
                          ]),
                        ),
                      if (GetPlatform.isMobile)
                        PopupMenuItem(
                          value: 'close',
                          child: Row(spacing: 12, children: [
                            const Icon(Icons.exit_to_app),
                            Text('Close',
                                style: Theme.of(context).textTheme.bodyLarge)
                          ]),
                        ),
                    ];
                  },
                  icon: const Icon(Icons.more_horiz),
                ),
                if (GetPlatform.isMobile)
                  IconButton(
                      onPressed: () async {
                        if (pageFailed || state != WebviewTabState.success) {
                          controller.removeKeepAlive(widget.initUrl);
                        }
                        if (Get.isBottomSheetOpen ?? false) {
                          Get.back();
                        }
                        await pausePlayingMedia();
                        Get.back(); // exit page
                      },
                      icon: SvgPicture.asset(
                        'assets/images/miniapp-exit.svg',
                        height: 28,
                        width: 28,
                        colorFilter: ColorFilter.mode(
                            Theme.of(context).iconTheme.color!,
                            BlendMode.srcIn),
                      )),
              ]),
          body: SafeArea(
              bottom: GetPlatform.isAndroid,
              child: Column(children: <Widget>[
                Expanded(
                    child: Stack(children: [
                  _getWebview(pageStorageKey, inAppWebViewKeepAlive),
                  Obx(() => tc.progress.value < 1.0
                      ? LinearProgressIndicator(
                          value:
                              tc.progress.value < 0.1 ? 0.1 : tc.progress.value)
                      : Container())
                ]))
              ])),
        )));
  }

  Widget _getWebview([PageStorageKey? key, InAppWebViewKeepAlive? keepAlive]) {
    return InAppWebView(
      key: key,
      keepAlive: GetPlatform.isDesktop ? null : keepAlive,
      webViewEnvironment: controller.webViewEnvironment,
      initialUrlRequest: URLRequest(url: WebUri(tc.url.value)),
      initialSettings: tc.settings,
      pullToRefreshController: pullToRefreshController,
      initialUserScripts: UnmodifiableListView([controller.textSizeUserScript]),
      onScrollChanged: (controller, x, y) async {
        // Save scroll position by current URL
        if (GetPlatform.isAndroid) {
          EasyDebounce.debounce(
            'saveScroll:${tc.url.value}',
            Duration(milliseconds: 500),
            () async {
              WebUri? uri = await controller.getUrl();
              if (uri == null) return;
              String currentUrl = uri.toString();
              if (currentUrl.isNotEmpty) {
                urlScrollPositions[currentUrl] = {
                  'scrollX': x,
                  'scrollY': y,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                };
              }
            },
          );
        }
      },
      onCreateWindow: GetPlatform.isDesktop
          ? (controller, createWindowAction) {
              if (createWindowAction.request.url == null) return false;
              String urlString = createWindowAction.request.url.toString();

              // Check for special URLs first
              handleSpecialUrls(urlString).then((handled) {
                if (handled) return;
                // If not a special URL, create new window
                this.controller.launchWebview(initUrl: urlString);
              });
              return true;
            }
          : null,
      onWebViewCreated: (controller) async {
        tc.setWebViewController(controller, widget.initUrl);
        await controller.evaluateJavascript(source: """
                        window.print = function(){};
                      """);

        controller.evaluateJavascript(source: "1 + 1").then((value) {
          if (value == 2) {
            state = WebviewTabState.success;
          }
        });

        controller.addJavaScriptHandler(
            handlerName: 'keychat-nostr', callback: javascriptHandlerNostr);
        controller.addJavaScriptHandler(
            handlerName: 'keychat-webln', callback: javascriptHandlerWebLN);
        // hide the progress bar
        if (widget.isCache == true) {
          tc.progress.value = 1.0;
        }
      },
      onLoadStart: (controller, uri) async {
        logger.d('onLoadStart: $uri');
        await _checkGoBackState(uri.toString());
      },
      onPrintRequest: (controller, url, printJobController) async {
        await printJobController?.cancel();
        return false;
      },
      onPermissionRequest: (controller, request) async {
        return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT);
      },
      onReceivedIcon: (controller, icon) {
        // logger.i('onReceivedIcon: ${icon.toString()}');
      },
      shouldOverrideUrlLoading:
          (controller, NavigationAction navigationAction) async {
        WebUri? uri = navigationAction.request.url;
        logger.i(
            'shouldOverrideUrlLoading: ${uri?.toString()} download: ${navigationAction.shouldPerformDownload}');
        if (uri == null) return NavigationActionPolicy.ALLOW;

        try {
          var str = uri.toString();

          // Handle special URLs
          if (await handleSpecialUrls(str)) {
            return NavigationActionPolicy.CANCEL;
          }

          if (isPdfUrl(str) &&
              !str.startsWith('https://docs.google.com/gview')) {
            final googleDocsUrl =
                'https://docs.google.com/gview?embedded=true&url=${Uri.encodeFull(str)}';
            logger.i('load pdf: $googleDocsUrl');
            await controller.loadUrl(
                urlRequest:
                    URLRequest(url: WebUri.uri(Uri.parse(googleDocsUrl))));
            return NavigationActionPolicy.CANCEL;
          }

          // download file

          final shouldPerformDownload =
              navigationAction.shouldPerformDownload ?? false;
          final url = navigationAction.request.url;
          if ((shouldPerformDownload && url != null) ||
              url.toString().startsWith("blob:") == true) {
            await downloadFile(url.toString());
            return NavigationActionPolicy.DOWNLOAD;
          }

          if (["http", "https", "data", "javascript", "about"]
              .contains(uri.scheme)) {
            return NavigationActionPolicy.ALLOW;
          }
          try {
            await launchUrl(uri);
          } catch (e) {
            if (e is PlatformException) {
              EasyLoading.showError('Failed to open link: ${e.message}');
              return NavigationActionPolicy.CANCEL;
            }
            logger.i(e.toString(), error: e);
            EasyLoading.showError('Failed to open link: ${e.toString()}');
          }
        } catch (e) {
          logger.i(e.toString(), error: e);
        }
        return NavigationActionPolicy.CANCEL;
      },
      onLoadStop: (controller, url) async {
        if (url == null) return;
        logger.d('onLoadStop: $url');
        await _checkGoBackState(url.toString());
        await controller.injectJavascriptFileFromAsset(
            assetFilePath: "assets/js/nostr.js");
        await controller.injectJavascriptFileFromAsset(
            assetFilePath: "assets/js/webln.js");
        pullToRefreshController?.endRefreshing();

        state = WebviewTabState.success;
        // Restore scroll position if needed
        if (GetPlatform.isAndroid && needRestorePosition) {
          needRestorePosition = false;
          restoreScrollPosition(url.toString());
        }
        if (url.host != initDomain) {
          needRestorePosition = true;
        }
      },
      onPageCommitVisible: (controller, url) {
        logger.i('onPageCommitVisible:${url.toString()}');
      },
      onReceivedServerTrustAuthRequest: (_, challenge) async {
        var sslError = challenge.protectionSpace.sslError;
        logger.i(
            'onReceivedServerTrustAuthRequest: ${challenge.protectionSpace.host} ${sslError?.code}');

        return ServerTrustAuthResponse(
            action: ServerTrustAuthResponseAction.PROCEED);
      },
      onReceivedHttpError: (controller, request, error) async {
        logger.i(
            'onReceivedHttpError: ${request.url.toString()} ${error.statusCode}');
      },
      onDidReceiveServerRedirectForProvisionalNavigation: (controller) async {
        logger.i(
            'onDidReceiveServerRedirectForProvisionalNavigation: ${await controller.getUrl()}');
      },
      onReceivedClientCertRequest: (controller, challenge) {
        logger.i(
            'onReceivedClientCertRequest: ${challenge.protectionSpace.host}');
        return ClientCertResponse(action: ClientCertResponseAction.PROCEED);
      },
      onProgressChanged: (controller, data) {
        if (data == 100) {
          state = WebviewTabState.success;
          pullToRefreshController?.endRefreshing();
        }
        tc.progress.value = data / 100;
      },
      onReceivedError: (InAppWebViewController controller,
          WebResourceRequest request, error) async {
        String url = request.url.toString();
        logger.i('onReceivedError: $url ${error.type} ${error.description}');
        var isForMainFrame = request.isForMainFrame ?? false;
        var isCancel = error.type == WebResourceErrorType.CANCELLED;
        if (!isForMainFrame || isCancel) {
          return;
        }
        this.controller.removeKeepAlive(widget.initUrl);
        pullToRefreshController?.endRefreshing();
        if (error.description.contains('domain=WebKitErrorDomain, code=102')) {
          return renderAssetAsHtml(controller, request);
        }
        if ((GetPlatform.isIOS ||
                GetPlatform.isMacOS ||
                GetPlatform.isWindows) &&
            error.type == WebResourceErrorType.CANCELLED) {
          // NSURLErrorDomain
          return;
        }
        if (GetPlatform.isWindows &&
            error.type == WebResourceErrorType.CONNECTION_ABORTED) {
          // CONNECTION_ABORTED
          return;
        }

        var errorUrl = request.url;
        pageFailed = true;
        await tc.webViewController?.loadData(data: """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <style>
    ${await InAppWebViewController.tRexRunnerCss}
    </style>
    <style>
    body {
        background-color: #f5f5f5;
        color: #333;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        font-size: 16px;
        line-height: 1.5;
    }
    .interstitial-wrapper {
        box-sizing: border-box;
        font-size: 1em;
        line-height: 1.6em;
        margin: 0 auto;
        max-width: 600px;
        width: 90%;
    }
    </style>
</head>
<body>
    ${await InAppWebViewController.tRexRunnerHtml}
    <div class="interstitial-wrapper">
      <h1>Website not available</h1>
      <p>Could not load web pages at <strong>$errorUrl</strong> because:</p>
      <p>${error.description}</p>
      <button onclick="window.pageFailedToRefresh();"  style="
        padding: 10px 30px;
        margin:0 auto;
        font-size: 18px;
        cursor: pointer;
        border: none;
        border-radius: 5px;">Refresh</button>
    </div>
</body>
    """, baseUrl: errorUrl, historyUrl: WebUri(widget.initUrl));
        await _checkGoBackState(url);
      },
      onConsoleMessage: (controller, consoleMessage) {
        if (kDebugMode) {
          print('console: ${consoleMessage.message}');
        }
      },
      onTitleChanged: (controller, title) async {
        if (title == null) return;
        updateTabInfo(widget.uniqueKey, tc.url.value, title);
      },
      onUpdateVisitedHistory: (controller, url, androidIsReload) {
        // logger.i('onUpdateVisitedHistory: ${url.toString()} $androidIsReload');
        onUpdateVisitedHistory(url);
      },
    );
  }

  // Add method to restore scroll position
  Future<void> restoreScrollPosition(String url) async {
    if (tc.webViewController == null || url.isEmpty) return;

    var savedPosition = urlScrollPositions[url];
    if (savedPosition != null) {
      try {
        // Wait for page to load before scrolling
        await Future.delayed(Duration(milliseconds: 500));

        await tc.webViewController!.scrollTo(
          x: savedPosition['scrollX'] ?? 0,
          y: savedPosition['scrollY'] ?? 0,
        );
      } catch (e) {
        logger.e('Failed to restore scroll position: $e');
      }
    }
  }

  Widget getPopTools(String url) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Theme.of(Get.context!).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(5)),
      child: Row(
        spacing: 4,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            padding: const EdgeInsets.all(0),
            onPressed: () {
              Get.back();
              Clipboard.setData(ClipboardData(text: url));
              EasyLoading.showToast('URL Copied');
            },
          ),
        ],
      ),
    );
  }

  void goBackOrPop() {
    tc.webViewController?.canGoBack().then((canGoBack) async {
      logger.i('goBackOrPop: canGoBack: $canGoBack');
      if (canGoBack) {
        await pausePlayingMedia();
        tc.webViewController?.goBack();
        return;
      }
      if (GetPlatform.isDesktop) {
        return;
      }
      if (pageFailed || state != WebviewTabState.success) {
        controller.removeKeepAlive(widget.initUrl);
      }
      await pausePlayingMedia();
      Get.back();
    });
  }

  // info coming from the JavaScript side!
  Future<Object?>? javascriptHandlerNostr(List<dynamic> data) async {
    logger.i('javascriptHandler: $data');
    var method = data[0];
    if (method == 'getRelays') {
      var relays = await RelayService.instance.getEnableList();
      return relays;
    }

    if (method == 'pageFailedToRefresh') {
      controller.removeKeepAlive(widget.initUrl);
      if (inAppWebViewKeepAlive == null) {
        refreshPage();
        return null;
      }

      setState(() {
        inAppWebViewKeepAlive = null;
      });
      return null;
    }

    WebUri? uri = await tc.webViewController?.getUrl();
    String? host = uri?.host;
    if (host == null) return null;
    Identity? identity = await getOrSelectIdentity(host);
    if (identity == null) {
      return null;
    }

    logger.i('selected: ${identity.secp256k1PKHex}');
    switch (method) {
      case 'getPublicKey':
        return identity.secp256k1PKHex;
      case 'signEvent':
        var event = data[1];

        // Confirm signing event
        if (!(controller.config['autoSignEvent'] ?? true)) {
          try {
            bool confirm = await Get.bottomSheet(signEventConfirm(
                content: event['content'] as String,
                kind: event['kind'] as int,
                tags: (event['tags'] as List)
                    .map((e) =>
                        List<String>.from((e.map((item) => item.toString()))))
                    .toList()));
            if (confirm != true) {
              return null;
            }
          } catch (e, s) {
            logger.e('Failed to parse event: $event', stackTrace: s);
            return null;
          }
        }
        var res = await NostrAPI.instance.signEventByIdentity(
            identity: identity,
            content: event['content'] as String,
            createdAt: event['created_at'],
            kind: event['kind'] as int,
            tags: (event['tags'] as List)
                .map((e) =>
                    List<String>.from((e.map((item) => item.toString()))))
                .toList());

        return res;
      case 'nip04Encrypt':
        String to = data[1];
        String plaintext = data[2];
        if (identity.isFromSigner) {
          var ciphertext = await SignerService.instance.nip04Encrypt(
              plaintext: plaintext,
              currentUser: identity.secp256k1PKHex,
              to: to);
          return ciphertext;
        }
        var encryptedEvent = await rust_nostr.getEncryptEvent(
            senderKeys: await identity.getSecp256k1SKHex(),
            receiverPubkey: to,
            content: plaintext);
        var model = NostrEventModel.fromJson(jsonDecode(encryptedEvent));
        return model.content;
      case 'nip04Decrypt':
        String from = data[1];
        String ciphertext = data[2];
        if (identity.isFromSigner) {
          var plaintext = await SignerService.instance.nip04Decrypt(
              ciphertext: ciphertext,
              currentUser: identity.secp256k1PKHex,
              from: from);
          return plaintext;
        }
        var content = await rust_nostr.decrypt(
            senderKeys: await identity.getSecp256k1SKHex(),
            receiverPubkey: from,
            content: ciphertext);
        return content;
      case 'nip44Encrypt':
        String to = data[1];
        String plaintext = data[2];
        String ciphertext;
        if (identity.isFromSigner) {
          ciphertext = await SignerService.instance
              .nip44Encrypt(plaintext, to, identity.secp256k1PKHex);
        } else {
          ciphertext = await rust_nostr.encryptNip44(
              senderKeys: await identity.getSecp256k1SKHex(),
              receiverPubkey: to,
              content: plaintext);
        }
        return ciphertext;
      case 'nip44Decrypt':
        String to = data[1];
        String ciphertext = data[2];
        if (identity.isFromSigner) {
          var plaintext = await SignerService.instance
              .nip44Decrypt(ciphertext, to, identity.secp256k1PKHex);
          return plaintext;
        }
        return await rust_nostr.decryptNip44(
            secretKey: await identity.getSecp256k1SKHex(),
            publicKey: to,
            content: ciphertext);
      default:
    }
    // return data to the JavaScript side!
    return 'Error: not implemented';
  }

  Future<Identity?> getOrSelectIdentity(String host) async {
    BrowserConnect? bc = await BrowserConnect.getByHost(host);
    if (bc != null) {
      Identity? identity =
          await IdentityService.instance.getIdentityByNostrPubkey(bc.pubkey);
      if (identity == null) {
        BrowserConnect.delete(bc.id);
      } else {
        // exist identity, auto return
        return identity;
      }
    }
    if (Get.isBottomSheetOpen ?? false) {
      return null;
    }
    // select a identity
    Identity? selected = await Get.bottomSheet(
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
        SelectIdentityForBrowser(host));
    if (selected != null) {
      EasyLoading.show(status: 'Processing...');
      try {
        String? favicon =
            await controller.getFavicon(tc.webViewController!, host);
        BrowserConnect bc = BrowserConnect(
            host: host, pubkey: selected.secp256k1PKHex, favicon: favicon);
        int id = await BrowserConnect.save(bc);
        bc.id = id;
        tc.setBrowserConnect(bc);
        EasyLoading.dismiss();
      } catch (e, s) {
        logger.e(e.toString(), stackTrace: s);
        EasyLoading.showError(e.toString());
      }
    }
    return selected;
  }

  Future popupMenuSelected(String value) async {
    final uri = await tc.webViewController?.getUrl();
    if (uri == null) return;

    switch (value) {
      case 'share':
        SharePlus.instance.share(ShareParams(uri: uri));
        break;
      case 'shareToRooms':
        Identity identity = Get.find<HomeController>().getSelectedIdentity();
        RoomUtil.forwardTextMessage(identity, uri.toString());
        break;
      case 'refresh':
        refreshPage();
        break;
      case 'bookmark':
        var exist = await DBProvider.database.browserBookmarks
            .filter()
            .urlEqualTo(uri.toString())
            .findFirst();
        if (exist == null) {
          logger.i('add bookmark: ${uri.toString()}');
          String? favicon = await controller
              .getFavicon(tc.webViewController!, uri.host)
              .timeout(const Duration(seconds: 3));
          String? siteTitle = await tc.webViewController?.getTitle();
          await BrowserBookmark.add(
              url: uri.toString(), favicon: favicon, title: siteTitle);
          EasyLoading.showSuccess('Added');
        } else {
          await Get.to(() => BookmarkEdit(model: exist));
        }
        break;
      case 'favorite':
        var exist = await BrowserFavorite.getByUrl(uri.toString());
        if (exist == null) {
          String? favicon = await controller
              .getFavicon(tc.webViewController!, uri.host)
              .timeout(const Duration(seconds: 10));
          String? siteTitle = await tc.webViewController?.getTitle();
          await BrowserFavorite.add(
              url: uri.toString(), favicon: favicon, title: siteTitle);
          EasyLoading.showSuccess('Added');
        } else {
          await Get.to(() => FavoriteEdit(favorite: exist));
        }
        await controller.loadFavorite();
        break;
      case 'copy':
        Clipboard.setData(ClipboardData(text: uri.toString()));
        EasyLoading.showToast('Copied');
        break;
      case 'clear':
        if (tc.webViewController == null) return;
        tc.webViewController?.webStorage.localStorage.clear();
        tc.webViewController?.webStorage.sessionStorage.clear();
        EasyLoading.showToast('Clear Success');
        refreshPage();
        break;
      case 'disconnect':
        var res = await BrowserConnect.getByHost(uri.host);
        if (res != null) {
          await BrowserConnect.delete(res.id);
        }
        tc.webViewController?.webStorage.localStorage.clear();
        tc.webViewController?.webStorage.sessionStorage.clear();
        EasyLoading.showToast('Logout Success');

        tc.setBrowserConnect(null);
        tc.canGoBack.value = false;
        tc.canGoForward.value = false;
        refreshPage();
        break;
      case 'close':
        try {
          controller.removeKeepAlive(widget.initUrl);
          await pausePlayingMedia();
        } catch (e, s) {
          logger.e('Error while closing webview: $e', stackTrace: s);
        }
        Get.back();
        break;
      case 'zoom':
        Get.bottomSheet(
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
            SafeArea(
              child: Scaffold(
                  appBar: AppBar(title: Text('Zoom Text')),
                  body: Container(
                      padding: const EdgeInsets.all(16),
                      child: Obx(() => Slider(
                          value: double.parse(
                              controller.kInitialTextSize.value.toString()),
                          min: 50,
                          max: 300,
                          divisions: 10,
                          label: '${controller.kInitialTextSize.value}',
                          onChanged: (value) {
                            tc.updateTextSize(value.toInt());
                          })))),
            ));
        break;
    }
  }

  Future onUpdateVisitedHistory(WebUri? uri) async {
    if (tc.webViewController == null || uri == null) return;
    EasyDebounce.debounce(
        'onUpdateVisitedHistory:${uri.toString()}', Duration(milliseconds: 200),
        () async {
      await _checkGoBackState(uri.toString());
      if (uri.toString() == 'about:blank') {
        return;
      }
      String? newTitle = await tc.webViewController?.getTitle();
      String title = newTitle ?? tc.title.value;
      if (title.isEmpty) {
        title = tc.title.value;
      }
      updateTabInfo(widget.uniqueKey, uri.toString(), title);
      controller.addHistory(uri.toString(), title);
      controller.getFavicon(tc.webViewController!, uri.host).then((favicon) {
        if (favicon != null && tc.favicon != favicon) {
          tc.favicon = favicon;
          controller.setTabDataFavicon(
              uniqueId: widget.uniqueKey, favicon: favicon);
        }
      });
    });
  }

  Future _checkGoBackState(String url) async {
    bool? canGoBack = await tc.webViewController?.canGoBack();
    bool? canGoForward = await tc.webViewController?.canGoForward();
    logger.i('$url canGoBack: $canGoBack, canGoForward: $canGoForward');
    tc.canGoBack.value = canGoBack ?? false;
    tc.canGoForward.value = canGoForward ?? false;
  }

  void updateTabInfo(String key, String url0, String title0) {
    // logger.i('updateTabInfo: $key, $url0, $title0');
    controller.setTabData(uniqueId: widget.uniqueKey, title: title0, url: url0);
    tc.title.value = title0;
    tc.url.value = url0;
  }

  Future<void> downloadFile(String url, [String? filename]) async {
    EasyThrottle.throttle('downloadFile', Duration(seconds: 3), () async {
      var permissionStatus = await Utils.getStoragePermission();
      bool hasStoragePermission = permissionStatus.isGranted;

      if (!hasStoragePermission) {
        EasyLoading.showToast('Storage permission not granted');
        return;
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        EasyLoading.showToast('No directory selected');
        return;
      }
      filename ??= url.split('/').last;
      final task = DownloadTask(
          url: url,
          filename: filename,
          directory: selectedDirectory,
          updates: Updates.statusAndProgress,
          retries: 2,
          allowPause: false);
      EasyLoading.showToast('Downloading $filename...');

      await FileDownloader().download(task, onProgress: (progress) {
        if (progress == 1.0) {
          EasyLoading.showToast('Download completed');
        }
      }, onStatus: (status) {
        logger.i('Status: $status');
      });
    });
  }

  Future renderAssetAsHtml(
      InAppWebViewController controller, WebResourceRequest request) async {
    String htmlContent = '''
<html>
<head>
<style>
html, body {
  height: 100%;
  margin: 0;
  padding: 0;
  background: #0e0e0e;
}
.container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  padding: 16px;
  box-sizing: border-box;
}
.img-wrapper {
  max-width: 100%;
  text-align: center;
}
img {
  max-width: 100%;
  height: auto;
  object-fit: contain;
}
</style>
</head>
<body>
  <div class="container">
    <div class="img-wrapper">
      <img src="${request.url.toString()}" alt="Image"/>
    </div>
  </div>
</body>
</html>
''';

    await controller.loadData(data: htmlContent, baseUrl: request.url);
  }

  // info coming from the JavaScript side!
  Future<Object?> javascriptHandlerWebLN(List<dynamic> data) async {
    logger.i('javascriptHandler: $data');
    var method = data[0];
    switch (method) {
      case 'getInfo':
        Identity? identity = Get.find<EcashController>().currentIdentity;
        identity ??= Get.find<HomeController>().getSelectedIdentity();
        return {
          'node': {
            'alias': identity.displayName,
            'pubkey': identity.secp256k1PKHex,
          }
        };
      case 'signMessage':
        Identity? identity = Get.find<EcashController>().currentIdentity;
        identity ??= Get.find<HomeController>().getSelectedIdentity();

        String message = data[1];
        String signature = await rust_nostr.signSchnorr(
            privateKey: await identity.getSecp256k1SKHex(), content: message);
        return {
          'signature': signature,
          'message': message,
        };
      case 'verifyMessage':
        Identity? identity = Get.find<EcashController>().currentIdentity;
        identity ??= Get.find<HomeController>().getSelectedIdentity();

        String signature = data[1];
        String message = data[2];
        bool isValid = await rust_nostr.verifySchnorr(
            pubkey: identity.secp256k1PKHex,
            content: message,
            sig: signature,
            hash: true);
        return isValid;
      case 'sendPayment':
        String? lnbc = data[1];
        if (lnbc == null || lnbc.isEmpty) {
          return 'Error: Invoice is empty';
        }
        try {
          Transaction? tr =
              await ecashController.proccessPayLightningBill(lnbc, isPay: true);
          if (tr == null) {
            return 'Error: Payment failed or cancelled';
          }
          return tr.token;
        } catch (e) {
          String msg = Utils.getErrorMessage(e);
          return 'Error: - $msg';
        }
      case 'makeInvoice':
        try {
          Map source = data[1];
          int amount = source['amount'] != null && source['amount'].isNotEmpty
              ? int.parse(source['amount'] ?? '0')
              : 0;
          int defaultAmount = source['defaultAmount'] != null &&
                  source['defaultAmount'].isNotEmpty
              ? int.parse(source['defaultAmount'] ?? '0')
              : 0;
          int invoiceAmount = amount > 0 ? amount : defaultAmount;
          Transaction? result = await Get.bottomSheet(
              ignoreSafeArea: false,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
              CreateInvoicePage(amount: invoiceAmount));
          if (result != null) {
            return result.token;
          }
        } catch (e, s) {
          logger.e(e.toString(), stackTrace: s);
        }

      default:
    }
    return null;
  }

  Widget signEventConfirm(
      {required String content,
      required int kind,
      required List<dynamic> tags}) {
    return Scaffold(
        appBar: AppBar(title: Text('Sign Event')),
        body: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event details
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kind section
                      _buildDetailSection(
                        title: 'Event Kind',
                        content: kind.toString(),
                        icon: Icons.category_outlined,
                      ),

                      const SizedBox(height: 20),

                      // Content section
                      _buildDetailSection(
                        title: 'Content',
                        content: content.isEmpty ? '(Empty)' : content,
                        icon: Icons.description_outlined,
                        isExpandable: content.length > 100,
                      ),

                      const SizedBox(height: 20),

                      // Tags section
                      _buildDetailSection(
                        title: 'Tags',
                        content: tags.isEmpty ? '(No tags)' : tags.toString(),
                        icon: Icons.label_outline,
                        isExpandable: tags.toString().length > 100,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Get.back(result: false);
                      },
                      child: Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Get.back(result: true);
                      },
                      child: Text('Sign Event'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  Widget _buildDetailSection({
    required String title,
    required String content,
    required IconData icon,
    bool isExpandable = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(Get.context!).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              Theme.of(Get.context!).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(Get.context!)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isExpandable && content.length > 100
                  ? '${content.substring(0, 100)}...'
                  : content,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: Theme.of(Get.context!).colorScheme.onSurface,
              ),
            ),
          ),
          if (isExpandable && content.length > 100)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () {
                  // Show full content in a dialog
                  Get.dialog(
                    AlertDialog(
                      title: Text(title),
                      content: SingleChildScrollView(
                        child: Text(
                          content,
                          style: TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                child: Text('Show full content'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> pausePlayingMedia() async {
    try {
      await tc.webViewController?.evaluateJavascript(source: """
      document.querySelectorAll('audio, video').forEach(media => media.pause());
    """).timeout(Duration(seconds: 2));
    } catch (e) {
      logger.e(e.toString(), error: e);
    }
  }

  Future<void> refreshPage([WebUri? uri]) async {
    EasyDebounce.debounce('webviewRefreshPage', Duration(seconds: 1), () async {
      try {
        uri ??= await tc.webViewController
            ?.getUrl()
            .timeout(Duration(seconds: 1), onTimeout: () {
          return WebUri(widget.initUrl);
        });
        await tc.webViewController
            ?.loadUrl(urlRequest: URLRequest(url: uri))
            .timeout(Duration(seconds: 3));
        loggerNoLine.i('Reloaded: ${uri.toString()}');
      } catch (e) {
        loggerNoLine.i('Reload failed: $e');

        // Recreate the webview by updating state
        InAppWebViewKeepAlive? newKa =
            await controller.refreshKeepAliveObject(widget.initUrl);
        setState(() {
          inAppWebViewKeepAlive = newKa;
          pageStorageKey = null;
        });
      }
    });
  }

  void initPullToRefreshController() {
    pullToRefreshController = kIsWeb ||
            ![TargetPlatform.iOS, TargetPlatform.android]
                .contains(defaultTargetPlatform)
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(color: KeychatGlobal.primaryColor),
            onRefresh: () async {
              if (tc.webViewController == null) {
                return refreshPage();
              }
              WebUri? url;
              try {
                url = await tc.webViewController
                    ?.getUrl()
                    .timeout(Duration(seconds: 1), onTimeout: () {
                  return WebUri(widget.initUrl);
                });
              } catch (e) {
                url = WebUri(widget.initUrl);
              }
              await refreshPage(url);
            });
  }

  // Add new method to handle special URLs
  Future<bool> handleSpecialUrls(String urlString) async {
    try {
      if (urlString.startsWith('cashu')) {
        ecashController.proccessCashuAString(urlString);
        return true;
      }
      // lightning invoice
      if (urlString.startsWith('lightning:')) {
        String str = urlString.replaceFirst('lightning:', '');
        if (isEmail(str) || str.toUpperCase().startsWith('LNURL')) {
          await Get.bottomSheet(
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
              PayInvoicePage(invoce: str, isPay: false, showScanButton: false));
          return true;
        }
        await ecashController.proccessPayLightningBill(str, isPay: true);
        return true;
      }
      if (urlString.startsWith('lnbc')) {
        await ecashController.proccessPayLightningBill(urlString, isPay: true);

        return true;
      }
    } catch (e) {
      logger.i(e.toString(), error: e);
    }
    return false;
  }
}
