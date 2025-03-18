import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:app/controller/home.controller.dart';
import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/models/browser/browser_connect.dart';
import 'package:app/models/browser/browser_favorite.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/identity.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/browser/BookmarkEdit.dart';
import 'package:app/page/browser/Browser_controller.dart';
import 'package:app/page/browser/FavoriteEdit.dart';
import 'package:app/page/browser/SelectIdentityForBrowser.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/service/SignerService.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final String defaultTitle = "Loading...";
  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      useShouldOverrideUrlLoading: true,
      transparentBackground: Get.isDarkMode,
      cacheEnabled: true,
      iframeAllow: "camera; microphone",
      algorithmicDarkeningAllowed: true,
      iframeAllowFullscreen: true);

  PullToRefreshController? pullToRefreshController;
  String url = "";
  double progress = 0;
  // bool marked = false;
  String title = "Loading...";
  bool canGoBack = false;
  bool canGoForward = false;
  late EcashController ecashController;
  late BrowserController browserController;
  BrowserConnect? browserConnect;

  @override
  void initState() {
    browserController = Get.find<BrowserController>();
    ecashController = Get.find<EcashController>();
    title = widget.title;
    url = widget.initUrl;
    super.initState();
    initBrowserConnect(WebUri(url));
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

  @override
  void dispose() {
    super.dispose();
    webViewController?.dispose();
  }

  void menuOpened() async {
    var uri = await webViewController?.getUrl();
    if (uri == null) return;
    setState(() {
      url = uri.toString();
    });
    initBrowserConnect(uri);
  }

  initBrowserConnect(WebUri uri) {
    BrowserConnect.getByHost(uri.host).then((value) {
      setState(() {
        browserConnect = value;
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
              leadingWidth: canGoForward ? 150 : 100,
              leading: Row(spacing: 0, children: [
                IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    onPressed: goBackOrPop,
                    icon: const Icon(Icons.arrow_back)),
                IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    onPressed: Get.back,
                    icon: const Icon(Icons.close)),
                if (canGoForward)
                  IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      onPressed: () {
                        webViewController?.goForward();
                      },
                      icon: const Icon(Icons.arrow_forward)),
              ]),
              centerTitle: true,
              title: Text(title),
              bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(0),
                  child: progress < 1.0
                      ? LinearProgressIndicator(value: progress)
                      : Container()),
              actions: [
                PopupMenuButton<String>(
                  onOpened: menuOpened,
                  onSelected: popupMenuSelected,
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem(
                        value: 'tools',
                        child: getPopTools(url),
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
                            final url = await webViewController?.getUrl();
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
                      if (browserConnect == null)
                        PopupMenuItem(
                          value: 'clear',
                          child: Row(spacing: 12, children: [
                            const Icon(Icons.storage),
                            Text('Clear Cache',
                                style: Theme.of(context).textTheme.bodyLarge)
                          ]),
                        ),
                      if (browserConnect != null)
                        PopupMenuItem(
                          value: 'disconnect',
                          child: Row(spacing: 12, children: [
                            const Icon(Icons.logout),
                            Text('ID Logout',
                                style: Theme.of(context).textTheme.bodyLarge)
                          ]),
                        ),
                    ];
                  },
                  icon: const Icon(Icons.more_horiz),
                ),
              ]),
          body: SafeArea(
              bottom: GetPlatform.isAndroid,
              child: InAppWebView(
                key: webViewKey,
                // keepAlive: keepAlive,
                // webViewEnvironment: browserController.webViewEnvironment,
                initialUrlRequest: URLRequest(url: WebUri(widget.initUrl)),
                initialSettings: settings,
                pullToRefreshController: pullToRefreshController,
                onWebViewCreated: (controller) {
                  webViewController = controller;
                  controller.addJavaScriptHandler(
                      handlerName: 'keychat', callback: javascriptHandler);
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
                    (controller, NavigationAction navigationAction) async {
                  WebUri? uri = navigationAction.request.url;
                  logger.d('shouldOverrideUrlLoading: ${uri?.toString()}');
                  if (uri == null) return NavigationActionPolicy.ALLOW;
                  try {
                    var str = uri.toString();
                    if (str.startsWith('cashu')) {
                      ecashController.proccessCashuAString(str);
                      return NavigationActionPolicy.CANCEL;
                    }
                    // lightning invoice
                    if (str.startsWith('lightning:')) {
                      str = str.replaceFirst('lightning:', '');
                      var tx = await ecashController
                          .proccessPayLightningBill(str, isPay: true);
                      if (tx != null) {
                        var lnTx = tx.field0 as LNTransaction;
                        logger.d('LN Transaction:   Amount=${lnTx.amount}, '
                            'INfo=${lnTx.info}, Description=${lnTx.fee}, '
                            'Hash=${lnTx.hash}, NodeId=${lnTx.status.name}');
                      }
                      return NavigationActionPolicy.CANCEL;
                    }
                    if (str.startsWith('lnbc')) {
                      var tx = await ecashController
                          .proccessPayLightningBill(str, isPay: true);
                      if (tx != null) {
                        logger.d((tx.field0 as LNTransaction).pr);
                      }

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
                    onUpdateVisitedHistory(uri);
                    return NavigationActionPolicy.ALLOW;
                  } catch (e) {
                    logger.d(e.toString(), error: e);
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStop: (controller, url) async {
                  onUpdateVisitedHistory(url);
                  await controller.injectJavascriptFileFromAsset(
                      assetFilePath: "assets/js/nostr.js");
                  pullToRefreshController?.endRefreshing();
                  setState(() {
                    this.url = url.toString();
                  });
                },
                onReceivedServerTrustAuthRequest: (_, challenge) async {
                  return ServerTrustAuthResponse(
                      action: ServerTrustAuthResponseAction.PROCEED);
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
                onConsoleMessage: (controller, consoleMessage) {
                  if (kDebugMode) {
                    print('console: ${consoleMessage.message}');
                  }
                },
                onTitleChanged: (controller, title) async {
                  if (title != null) {
                    setState(() {
                      this.title = title;
                    });
                  }
                },
                onUpdateVisitedHistory: (controller, url, androidIsReload) {
                  onUpdateVisitedHistory(url);
                },
              )),
        ));
  }

  Widget getPopTools(String url) {
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
          Expanded(
            child: Text(
              url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
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
    webViewController?.canGoBack().then((canGoBack) {
      if (canGoBack) {
        webViewController?.goBack();
      } else {
        Navigator.of(Get.context!).pop();
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
    if (method == 'getRelays') {
      var relays = await RelayService.instance.getEnableList();
      return relays;
    }

    WebUri? uri = await webViewController?.getUrl();
    if (uri == null) return;
    String host = uri.host;
    Identity? identity = await getOrSelectIdentity(host);
    if (identity == null) {
      return null;
    }

    logger.d('selected: ${identity.secp256k1PKHex}');
    switch (method) {
      case 'getPublicKey':
        return identity.secp256k1PKHex;
      case 'signEvent':
        var event = data.args[1];
        if (identity.isFromSigner) {
          return await SignerService.instance.signEvent(
              pubkey: identity.secp256k1PKHex, eventJson: jsonEncode(event));
        }
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
      case 'nip04Encrypt':
        String to = data.args[1];
        String plaintext = data.args[2];
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
        String from = data.args[1];
        String ciphertext = data.args[2];
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
        String to = data.args[1];
        String plaintext = data.args[2];
        String encryptedEvent;
        if (identity.isFromSigner) {
          encryptedEvent = await SignerService.instance.getNip59EventString(
              from: identity.secp256k1PKHex, to: to, content: plaintext);
          logger.d(encryptedEvent);
        } else {
          encryptedEvent = await rust_nostr.createGiftJson(
              senderKeys: await identity.getSecp256k1SKHex(),
              receiverPubkey: to,
              kind: 14,
              content: plaintext);
        }
        var model = NostrEventModel.fromJson(jsonDecode(encryptedEvent));
        return model.content;
      case 'nip44Decrypt':
        String to = data.args[1];
        String ciphertext = data.args[2];
        if (identity.isFromSigner) {
          var subEvent = await SignerService.instance
              .nip44Decrypt(NostrEventModel.fromJson(jsonDecode(ciphertext)));
          return subEvent.content;
        }
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
    Identity? selected = await Get.bottomSheet(SelectIdentityForBrowser(host));
    if (selected != null) {
      EasyLoading.show(status: 'Processing...');
      try {
        String? favicon =
            await browserController.getFavicon(webViewController!, host);
        BrowserConnect bc = BrowserConnect(
            host: host, pubkey: selected.secp256k1PKHex, favicon: favicon);
        int id = await BrowserConnect.save(bc);
        bc.id = id;
        setState(() {
          browserConnect = bc;
        });
        EasyLoading.dismiss();
      } catch (e, s) {
        logger.e(e.toString(), stackTrace: s);
        EasyLoading.showError(e.toString());
      }
    }
    return selected;
  }

  Future popupMenuSelected(String value) async {
    final uri = await webViewController?.getUrl();
    if (uri == null) return;

    switch (value) {
      case 'share':
        Share.share(uri.toString());
        break;
      case 'shareToRooms':
        Identity identity = Get.find<HomeController>().getSelectedIdentity();
        RoomUtil.forwardTextMessage(identity, uri.toString());
        break;
      case 'refresh':
        webViewController?.reload();
        break;
      case 'bookmark':
        var exist = await DBProvider.database.browserBookmarks
            .filter()
            .urlEqualTo(uri.toString())
            .findFirst();
        if (exist == null) {
          String? favicon = await browserController
              .getFavicon(webViewController!, uri.host)
              .timeout(const Duration(seconds: 10));
          String? siteTitle = title == defaultTitle
              ? await webViewController?.getTitle()
              : title;
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
          String? favicon = await browserController
              .getFavicon(webViewController!, uri.host)
              .timeout(const Duration(seconds: 10));
          String? siteTitle = title == defaultTitle
              ? await webViewController?.getTitle()
              : title;
          await BrowserFavorite.add(
              url: uri.toString(), favicon: favicon, title: siteTitle);
          EasyLoading.showSuccess('Added');
        } else {
          await Get.to(() => FavoriteEdit(favorite: exist));
        }
        await browserController.loadFavorite();
        break;
      case 'copy':
        Clipboard.setData(ClipboardData(text: uri.toString()));
        EasyLoading.showToast('Copied');
        break;
      case 'clear':
        if (webViewController == null) return;
        webViewController?.webStorage.localStorage.clear();
        webViewController?.webStorage.sessionStorage.clear();
        EasyLoading.showToast('Clear Success');
        webViewController?.reload();
        break;
      case 'disconnect':
        var res = await BrowserConnect.getByHost(uri.host);
        if (res != null) {
          await BrowserConnect.delete(res.id);
        }
        webViewController?.webStorage.localStorage.clear();
        webViewController?.webStorage.sessionStorage.clear();
        EasyLoading.showToast('Logout Success');
        setState(() {
          browserConnect = null;
          canGoBack = false;
          canGoForward = false;
        });
        webViewController?.reload();
        break;
    }
  }

  onUpdateVisitedHistory(WebUri? uri) async {
    if (webViewController == null) return;
    EasyDebounce.debounce('urlHistoryUpdate', const Duration(milliseconds: 500),
        () async {
      bool? canGoBack = await webViewController?.canGoBack();
      bool? canGoForward = await webViewController?.canGoForward();
      logger.d('canGoBack: $canGoBack, canGoForward: $canGoForward');
      setState(() {
        this.canGoBack = canGoBack ?? false;
        this.canGoForward = canGoForward ?? false;
        url = uri.toString();
      });
      // fetch new title
      String? newTitle = await webViewController!.getTitle();
      String? favicon =
          await browserController.getFavicon(webViewController!, uri!.host);
      browserController.addHistory(url.toString(), newTitle ?? title, favicon);
    });
  }
}
