import 'dart:convert' show jsonDecode;

import 'package:app/controller/home.controller.dart';
import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/browser/Browser_controller.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class BrowserDetailPage extends StatefulWidget {
  final String initUrl;
  final String title;
  const BrowserDetailPage(this.initUrl, this.title, {super.key});

  @override
  _BrowserDetailPageState createState() => _BrowserDetailPageState();
}

class _BrowserDetailPageState extends State<BrowserDetailPage> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      useShouldOverrideUrlLoading: true,
      cacheEnabled: true,
      iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true);

  PullToRefreshController? pullToRefreshController;
  String url = "";
  double progress = 0;
  bool marked = false;
  String title = "Loading...";
  bool canGoBack = false;
  late EcashController ecashController;
  @override
  void initState() {
    ecashController = Get.find<EcashController>();
    super.initState();
    setState(() {
      title = widget.title;
      url = widget.initUrl;
    });
    pullToRefreshController = kIsWeb ||
            ![TargetPlatform.iOS, TargetPlatform.android]
                .contains(defaultTargetPlatform)
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(color: Colors.purple),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(
                    urlRequest:
                        URLRequest(url: await webViewController?.getUrl()));
              }
            },
          );
  }

  void initIsMarked() {
    webViewController?.getUrl().then((value) async {
      if (value == null) return;
      BrowserBookmark? bb = await DBProvider.database.browserBookmarks
          .filter()
          .urlEqualTo(value.toString())
          .findFirst();

      setState(() {
        url = value.toString();
        marked = bb != null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            toolbarHeight: 40,
            titleSpacing: 0,
            leadingWidth: canGoBack ? 100 : 50,
            leading: Row(children: [
              IconButton(
                  onPressed: () async {
                    goBackOrPop();
                  },
                  icon: const Icon(Icons.arrow_back)),
              if (canGoBack)
                IconButton(
                    onPressed: () {
                      Get.back();
                    },
                    icon: const Icon(Icons.close))
            ]),
            centerTitle: true,
            title: Text(title),
            actions: [
              PopupMenuButton<String>(
                onOpened: () {
                  initIsMarked();
                },
                onSelected: (value) async {
                  final url = await webViewController?.getUrl();
                  if (url == null) return;

                  switch (value) {
                    case 'share':
                      Share.share(url.toString());
                      break;
                    case 'copy':
                      Clipboard.setData(ClipboardData(text: url.toString()));
                      EasyLoading.showToast('Copied');
                      break;
                    case 'openInBrowser':
                      await launchUrl(Uri.parse(url.toString()),
                          mode: LaunchMode.externalApplication);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    PopupMenuItem(
                      value: 'tools',
                      child: getPopTools(),
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
                      value: 'copy',
                      child: Row(spacing: 12, children: [
                        const Icon(CupertinoIcons.doc_on_clipboard),
                        Text('Copy',
                            style: Theme.of(context).textTheme.bodyLarge)
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'openInBrowser',
                      child: Row(spacing: 12, children: [
                        const Icon(CupertinoIcons.globe),
                        Text('Native Browser',
                            style: Theme.of(context).textTheme.bodyLarge)
                      ]),
                    ),
                  ];
                },
                icon: const Icon(Icons.more_vert),
              ),
            ]),
        body: PopScope(
            canPop: GetPlatform.isAndroid ? false : true,
            onPopInvokedWithResult: (didPop, d) {
              if (didPop) {
                return;
              }
              goBackOrPop();
            },
            child: SafeArea(
                child: Column(children: <Widget>[
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      key: webViewKey,
                      initialUrlRequest:
                          URLRequest(url: WebUri(widget.initUrl)),
                      initialSettings: settings,
                      pullToRefreshController: pullToRefreshController,
                      onWebViewCreated: (controller) {
                        webViewController = controller;

                        controller.addJavaScriptHandler(
                            handlerName: 'keychat',
                            callback: javascriptHandler);
                      },
                      onLoadStart: (controller, url) async {
                        setState(() {
                          this.url = url.toString();
                        });
                      },
                      onPermissionRequest: (controller, request) async {
                        return PermissionResponse(
                            resources: request.resources,
                            action: PermissionResponseAction.GRANT);
                      },
                      shouldOverrideUrlLoading:
                          (controller, navigationAction) async {
                        var uri = navigationAction.request.url!;
                        var str = uri.toString();
                        if (str.startsWith('cashu')) {
                          ecashController.proccessCashuAString(str);
                          return NavigationActionPolicy.CANCEL;
                        }
                        // lighting invoice
                        if (str.startsWith('lightning:')) {
                          str = str.replaceFirst('lightning:', '');
                          ecashController.proccessPayLightingBill(str,
                              pay: true);
                          return NavigationActionPolicy.CANCEL;
                        }
                        if (str.startsWith('lnbc')) {
                          ecashController.proccessPayLightingBill(str,
                              pay: true);
                          return NavigationActionPolicy.CANCEL;
                        }

                        if (![
                          "http",
                          "https",
                          "file",
                          "chrome",
                          "data",
                          "javascript",
                          "about"
                        ].contains(uri.scheme)) {
                          if (await canLaunchUrl(uri)) {
                            // Launch the App
                            await launchUrl(uri);
                            // and cancel the request
                            return NavigationActionPolicy.CANCEL;
                          }
                        }
                        return NavigationActionPolicy.ALLOW;
                      },
                      onLoadStop: (controller, url) async {
                        await controller.injectJavascriptFileFromAsset(
                            assetFilePath: "assets/js/nostr.js");
                        pullToRefreshController?.endRefreshing();
                        setState(() {
                          this.url = url.toString();
                          // urlController.text = this.url;
                        });
                      },
                      onReceivedError: (controller, request, error) {
                        pullToRefreshController?.endRefreshing();
                      },
                      onProgressChanged: (controller, progress) {
                        if (progress == 100) {
                          pullToRefreshController?.endRefreshing();
                        }
                        setState(() {
                          this.progress = progress / 100;
                          // urlController.text = url;
                        });
                      },
                      onUpdateVisitedHistory:
                          (controller, url, androidIsReload) async {
                        bool? can = await webViewController?.canGoBack();
                        Get.find<BrowserController>().addHistory(url.toString(),
                            await controller.getTitle() ?? title);
                        setState(() {
                          canGoBack = can ?? false;
                          this.url = url.toString();
                        });
                      },
                      onConsoleMessage: (controller, consoleMessage) {
                        if (kDebugMode) {
                          print('console: $consoleMessage');
                        }
                      },
                      onTitleChanged: (controller, title) => setState(() {
                        if (title != null) {
                          setState(() {
                            this.title = title;
                          });
                        }
                      }),
                    ),
                    progress < 1.0
                        ? LinearProgressIndicator(value: progress)
                        : Container(),
                  ],
                ),
              ),
            ]))));
  }

  Widget getPopTools() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        spacing: 4,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FutureBuilder<bool>(
            future: webViewController?.canGoBack(),
            builder: (context, snapshot) {
              bool canGoBack = snapshot.data ?? false;
              return IconButton(
                icon: const Icon(CupertinoIcons.arrow_left),
                onPressed: () async {
                  if (canGoBack) {
                    webViewController?.goBack();
                    Get.back();
                  }
                },
                color:
                    canGoBack ? Theme.of(context).iconTheme.color : Colors.grey,
              );
            },
          ),
          FutureBuilder<bool>(
              future: webViewController?.canGoForward(),
              builder: (context, snapshot) {
                bool can = snapshot.data ?? false;
                return IconButton(
                  icon: const Icon(CupertinoIcons.arrow_right),
                  onPressed: () async {
                    if (can) {
                      webViewController?.goForward();
                      Get.back();
                    }
                  },
                  color: can ? Theme.of(context).iconTheme.color : Colors.grey,
                );
              }),
          IconButton(
            icon: marked
                ? const Icon(CupertinoIcons.star_fill)
                : const Icon(CupertinoIcons.star),
            onPressed: () {
              troggleMarkUrl();
              Get.back();
            },
          ),
          IconButton(
              onPressed: () {
                webViewController?.reload();
                Get.back();
              },
              icon: const Icon(CupertinoIcons.refresh)),
        ],
      ),
    );
  }

  void troggleMarkUrl() async {
    final url = await webViewController?.getUrl();
    if (url == null) return;
    BrowserBookmark? bb = await DBProvider.database.browserBookmarks
        .filter()
        .urlEqualTo(url.toString())
        .findFirst();
    await DBProvider.database.writeTxn(() async {
      if (bb != null) {
        await DBProvider.database.browserBookmarks.delete(bb.id);
      } else {
        BrowserBookmark bookmark = BrowserBookmark(
            url: url.toString(), title: await webViewController?.getTitle());
        await DBProvider.database.browserBookmarks.put(bookmark);
      }
    });
    setState(() {
      marked = !marked;
    });
    EasyLoading.showToast(marked ? 'Bookmarked' : 'Unbookmarked');
  }

  void goBackOrPop() {
    webViewController?.canGoBack().then((canGoBack) {
      if (canGoBack) {
        webViewController?.goBack();
      } else {
        Navigator.pop(Get.context!);
      }
    });
  }

  // info coming from the JavaScript side!
  javascriptHandler(JavaScriptHandlerFunctionData data) async {
    if (!data.isMainFrame) {
      throw Exception('Invalid host');
    }
    logger.d('javascriptHandler: $data');
    var method = data.args[0];
    switch (method) {
      case 'getPublicKey':
        var identity = Get.find<HomeController>().getSelectedIdentity();
        return identity.secp256k1PKHex;
      case 'signEvent':
        var identity = Get.find<HomeController>().getSelectedIdentity();
        var event = data.args[1];
        var res = await rust_nostr.signEvent(
            senderKeys: await identity.getSecp256k1SKHex(),
            content: event['content'] as String,
            createdAt: BigInt.from(event['created_at']),
            kind: event['kind'] as int,
            tags: (event['tags'] as List)
                .map((e) => List<String>.from(e))
                .toList());
        logger.d('signEvent: $res');
        return res;
      case 'getRelays':
        var relays = await RelayService.instance.getEnableList();
        return relays;
      case 'nip04Encrypt':
        String to = data.args[1];
        String plaintext = data.args[2];
        var identity = Get.find<HomeController>().getSelectedIdentity();

        var encryptedEvent = await rust_nostr.getEncryptEvent(
            senderKeys: await identity.getSecp256k1SKHex(),
            receiverPubkey: to,
            content: plaintext);
        var model = NostrEventModel.fromJson(jsonDecode(encryptedEvent));
        return model.content;
      case 'nip04Decrypt':
        String to = data.args[1];
        String ciphertext = data.args[2];
        var identity = Get.find<HomeController>().getSelectedIdentity();

        var encryptedEvent = await rust_nostr.decrypt(
            senderKeys: await identity.getSecp256k1SKHex(),
            receiverPubkey: to,
            content: ciphertext);
        var model = NostrEventModel.fromJson(jsonDecode(encryptedEvent));
        return model.content;
      case 'nip44Encrypt':
        break;
      case 'nip44Decrypt':
        break;
      default:
    }
    // return data to the JavaScript side!
    return 1111;
  }
}
