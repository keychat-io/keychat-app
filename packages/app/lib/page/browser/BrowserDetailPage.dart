import 'dart:convert' show jsonDecode;

import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/models/browser/browser_connect.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/identity.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/browser/Browser_controller.dart';
import 'package:app/service/identity.service.dart';
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
import 'package:settings_ui/settings_ui.dart';
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
      transparentBackground: true,
      cacheEnabled: true,
      iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true);

  PullToRefreshController? pullToRefreshController;
  String url = "";
  double progress = 0;
  // bool marked = false;
  String title = "Loading...";
  bool canGoBack = false;
  late EcashController ecashController;
  late BrowserController browserController;
  @override
  void initState() {
    browserController = Get.find<BrowserController>();
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

      setState(() {
        url = value.toString();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, d) {
          if (didPop) {
            return;
          }
          goBackOrPop();
        },
        child: Scaffold(
            appBar: AppBar(
                toolbarHeight: 40,
                titleSpacing: 0,
                leadingWidth: canGoBack ? 100 : 50,
                leading: Row(children: [
                  IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: goBackOrPop,
                      icon: const Icon(Icons.arrow_back)),
                  if (canGoBack)
                    IconButton(
                        onPressed: Get.back, icon: const Icon(Icons.close))
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
                          Clipboard.setData(
                              ClipboardData(text: url.toString()));
                          EasyLoading.showToast('Copied');
                          break;
                        case 'clear':
                          if (webViewController == null) return;
                          webViewController?.webStorage.localStorage.clear();
                          webViewController?.webStorage.sessionStorage.clear();
                          EasyLoading.showToast('Clear Success');
                          webViewController?.reload();
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
                          value: 'clear',
                          child: Row(spacing: 12, children: [
                            const Icon(Icons.storage),
                            Text('Clear Local Storage',
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
                    icon: const Icon(Icons.more_horiz),
                  ),
                ]),
            body: SafeArea(
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
                        });
                      },
                      onUpdateVisitedHistory:
                          (controller, url, androidIsReload) async {
                        bool? can = await webViewController?.canGoBack();
                        setState(() {
                          canGoBack = can ?? false;
                          this.url = url.toString();
                        });
                        // fetch new title
                        String? newTitle = await controller.getTitle();
                        String? favicon =
                            await browserController.getFavicon(controller);
                        if (newTitle == null) {
                          Future.delayed(const Duration(seconds: 1))
                              .then((e) async {
                            browserController.addHistory(url.toString(),
                                await controller.getTitle() ?? title, favicon);
                          });
                        } else {
                          browserController.addHistory(
                              url.toString(), newTitle, favicon);
                        }
                      },
                      onConsoleMessage: (controller, consoleMessage) {
                        if (kDebugMode) {
                          print('console: $consoleMessage');
                        }
                      },
                      onTitleChanged: (controller, title) async {
                        if (title != null) {
                          setState(() {
                            this.title = title;
                          });
                        }
                      },
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
          FutureBuilder(future: () async {
            final url = await webViewController?.getUrl();
            if (url == null) return null;
            return await DBProvider.database.browserBookmarks
                .filter()
                .urlEqualTo(url.toString())
                .findFirst();
          }(), builder: (context, snapshot) {
            BrowserBookmark? bb = snapshot.data;
            return IconButton(
              icon: bb != null
                  ? const Icon(CupertinoIcons.star_fill)
                  : const Icon(CupertinoIcons.star),
              onPressed: () {
                troggleMarkUrl(bb);
                Get.back();
              },
            );
          }),
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

  void troggleMarkUrl(BrowserBookmark? bb) async {
    if (webViewController == null) return;

    if (bb != null) {
      await BrowserBookmark.delete(bb.id);
    } else {
      final url = await webViewController?.getUrl();
      if (url == null) return;
      String? favicon = await browserController.getFavicon(webViewController!);
      await DBProvider.database.writeTxn(() async {
        BrowserBookmark bookmark = BrowserBookmark(
            url: url.toString(),
            title: await webViewController?.getTitle(),
            favicon: favicon);
        await DBProvider.database.browserBookmarks.put(bookmark);
      });
    }

    EasyLoading.showSuccess('Success');
    browserController.loadBookmarks();
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
    WebUri? uri = await webViewController?.getUrl();
    if (uri == null) return;
    String host = uri.host;
    Identity? identity = await getOrSelectIdentity(host);
    if (identity == null) {
      // EasyLoading.showError('No identity selected');
      return null;
    }

    logger.d('selected: ${identity.secp256k1PKHex}');
    switch (method) {
      case 'getPublicKey':
        return identity.secp256k1PKHex;
      case 'signEvent':
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

        var encryptedEvent = await rust_nostr.getEncryptEvent(
            senderKeys: await identity.getSecp256k1SKHex(),
            receiverPubkey: to,
            content: plaintext);
        var model = NostrEventModel.fromJson(jsonDecode(encryptedEvent));
        return model.content;
      case 'nip04Decrypt':
        String to = data.args[1];
        String ciphertext = data.args[2];

        var content = await rust_nostr.decrypt(
            senderKeys: await identity.getSecp256k1SKHex(),
            receiverPubkey: to,
            content: ciphertext);
        return content;
      case 'nip44Encrypt':
        String to = data.args[1];
        String plaintext = data.args[2];
        var encryptedEvent = await rust_nostr.createGiftJson(
            senderKeys: await identity.getSecp256k1SKHex(),
            receiverPubkey: to,
            kind: 14,
            content: plaintext);
        var model = NostrEventModel.fromJson(jsonDecode(encryptedEvent));
        return model.content;
      case 'nip44Decrypt':
        String to = data.args[1];
        String ciphertext = data.args[2];
        rust_nostr.NostrEvent event = await rust_nostr.decryptGift(
            senderKeys: await identity.getSecp256k1SKHex(),
            receiver: to,
            content: ciphertext);
        return event.content;
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
    List<Identity> identities =
        await IdentityService.instance.getEnableBrowserIdentityList();
    Identity? selected = await Get.bottomSheet(
        SettingsList(platform: DevicePlatform.iOS, sections: [
      SettingsSection(
          title: Text('Request to Login: $host',
              style: Theme.of(Get.context!).textTheme.titleMedium),
          tiles: identities
              .map((iden) => SettingsTile(
                  leading: getRandomAvatar(iden.secp256k1PKHex,
                      height: 30, width: 30),
                  value: Text(getPublicKeyDisplay(iden.npub)),
                  title: Text(iden.displayName),
                  onPressed: (context) async {
                    EasyLoading.show(status: 'Proccessing...');
                    try {
                      String? favicon = await browserController
                          .getFavicon(webViewController!);
                      BrowserConnect bc = BrowserConnect(
                          host: host,
                          pubkey: iden.secp256k1PKHex,
                          favicon: favicon);
                      await BrowserConnect.save(bc);
                      EasyLoading.dismiss();
                      Get.back(result: iden);
                    } catch (e, s) {
                      logger.e(e.toString(), stackTrace: s);
                      EasyLoading.showError(e.toString());
                    }
                  }))
              .toList())
    ]));
    return selected;
  }
}
