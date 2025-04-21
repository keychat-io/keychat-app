import 'dart:convert' show jsonDecode;

import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/browser/BookmarkEdit.dart';
import 'package:app/page/browser/BrowserHome.dart';
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

class WebviewTab extends StatefulWidget {
  final String uniqueKey;
  final String initUrl;
  final String? initTitle;
  final int windowId;
  const WebviewTab({
    super.key,
    required this.windowId,
    required this.uniqueKey,
    required this.initUrl,
    this.initTitle,
  });
  @override
  _WebviewTabState createState() => _WebviewTabState();
}

class _WebviewTabState extends State<WebviewTab> {
  late EcashController ecashController;
  late MultiWebviewController controller;
  late WebviewTabController tc;
  late String title;
  late String url;
  double progress = 0.2;
  String? favicon;

  @override
  void initState() {
    url = widget.initUrl;
    title = widget.initTitle ?? url;
    controller = Get.find<MultiWebviewController>();
    tc = Get.put(WebviewTabController(), tag: widget.uniqueKey);
    ecashController = Get.find<EcashController>();
    initBrowserConnect(WebUri(widget.initUrl));
    super.initState();
  }

  void menuOpened() async {
    var uri = await tc.webViewController?.getUrl();
    if (uri == null) return;
    initBrowserConnect(uri);
    if (uri.toString() != url) return;
    controller.updateTabData(uniqueId: widget.uniqueKey, url: uri.toString());
  }

  initBrowserConnect(WebUri uri) {
    BrowserConnect.getByHost(uri.host).then((value) {
      tc.setBrowserConnect(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initUrl == KeychatGlobal.newTab) return BrowserHome();

    return Obx(() => PopScope(
        canPop: !tc.canGoBack.value,
        onPopInvokedWithResult: (didPop, d) {
          if (didPop) {
            return;
          }
          goBackOrPop();
        },
        child: Scaffold(
          appBar: AppBar(
              titleSpacing: 0,
              leadingWidth: 0,
              toolbarHeight: GetPlatform.isDesktop ? 48 : 40,
              leading: Container(),
              title: Row(spacing: 8, children: [
                Obx(() => Row(children: [
                      IconButton(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          onPressed: goBackOrPop,
                          icon: const Icon(Icons.arrow_back)),
                      IconButton(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          onPressed: () {
                            if (GetPlatform.isMobile) {
                              Get.back();
                            } else {
                              controller.removeTab(widget.uniqueKey);
                            }
                          },
                          icon: const Icon(Icons.close)),
                      tc.canGoForward.value
                          ? IconButton(
                              onPressed: () {
                                tc.webViewController?.goForward();
                              },
                              icon: const Icon(Icons.arrow_forward))
                          : Container(),
                      if (GetPlatform.isDesktop)
                        IconButton(
                            onPressed: () {
                              tc.webViewController?.reload();
                            },
                            icon: const Icon(Icons.refresh)),
                    ])),
                Expanded(
                    child: Center(
                        child: AutoSizeText(title,
                            minFontSize: 10,
                            stepGranularity: 2,
                            maxFontSize: 16,
                            maxLines: 1,
                            overflow: TextOverflow.clip)))
              ]),
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
                      if (tc.browserConnect.value.host == "")
                        PopupMenuItem(
                          value: 'clear',
                          child: Row(spacing: 12, children: [
                            const Icon(Icons.storage),
                            Text('Clear Cache',
                                style: Theme.of(context).textTheme.bodyLarge)
                          ]),
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
                    ];
                  },
                  icon: const Icon(Icons.more_horiz),
                ),
              ]),
          body: SafeArea(
              bottom: GetPlatform.isAndroid,
              child: Column(children: <Widget>[
                Expanded(
                    child: Stack(children: [
                  InAppWebView(
                    key: PageStorageKey(widget.uniqueKey),
                    // keepAlive: keepAlive,
                    // webViewEnvironment: browserController.webViewEnvironment,
                    initialUrlRequest: URLRequest(url: WebUri(widget.initUrl)),
                    initialSettings: tc.settings,
                    pullToRefreshController: tc.pullToRefreshController,
                    onWebViewCreated: (controller) {
                      tc.webViewController = controller;
                      controller.addJavaScriptHandler(
                          handlerName: 'keychat', callback: javascriptHandler);
                    },
                    onLoadStart: (controller, uri) async {
                      if (uri == null) return;
                      if (uri.toString() == url) return;
                      updateTabInfo(
                          widget.uniqueKey, uri.toString(), title, favicon);
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
                        return NavigationActionPolicy.ALLOW;
                      } catch (e) {
                        logger.d(e.toString(), error: e);
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                    onLoadStop: (controller, url) async {
                      onUpdateVisitedHistory(url);
                      controller.injectJavascriptFileFromAsset(
                          assetFilePath: "assets/js/nostr.js");
                      tc.pullToRefreshController?.endRefreshing();
                    },
                    onReceivedServerTrustAuthRequest: (_, challenge) async {
                      return ServerTrustAuthResponse(
                          action: ServerTrustAuthResponseAction.PROCEED);
                    },
                    onReceivedError: (controller, request, error) {
                      tc.pullToRefreshController?.endRefreshing();
                    },
                    onProgressChanged: (controller, data) {
                      if (data == 100) {
                        tc.pullToRefreshController?.endRefreshing();
                      }
                      setState(() {
                        progress = data / 100;
                      });
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      if (kDebugMode) {
                        print('console: ${consoleMessage.message}');
                      }
                    },
                    onTitleChanged: (controller, title) async {
                      if (title == null) return;
                      updateTabInfo(widget.uniqueKey, url, title, favicon);
                    },
                    onUpdateVisitedHistory: (controller, url, androidIsReload) {
                      // onUpdateVisitedHistory(url);
                    },
                  ),
                  progress < 1.0
                      ? LinearProgressIndicator(value: progress)
                      : Container()
                ]))
              ])),
        )));
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
    tc.webViewController?.canGoBack().then((canGoBack) {
      if (canGoBack) {
        tc.webViewController?.goBack();
      } else {
        if (GetPlatform.isDesktop) {
          controller.removeTab(widget.uniqueKey);
        } else {
          Get.back();
        }
      }
    });
  }

  // info coming from the JavaScript side!
  javascriptHandler(List<dynamic> data) async {
    logger.d('javascriptHandler: $data');
    var method = data[0];
    if (method == 'getRelays') {
      var relays = await RelayService.instance.getEnableList();
      return relays;
    }

    WebUri? uri = await tc.webViewController?.getUrl();
    String host = uri?.host ?? url;
    Identity? identity = await getOrSelectIdentity(host);
    if (identity == null) {
      return null;
    }

    logger.d('selected: ${identity.secp256k1PKHex}');
    switch (method) {
      case 'getPublicKey':
        return identity.secp256k1PKHex;
      case 'signEvent':
        var event = data[1];

        var res = await NostrAPI.instance.signEventByIdentity(
            identity: identity,
            content: event['content'] as String,
            createdAt: event['created_at'],
            kind: event['kind'] as int,
            tags: (event['tags'] as List)
                .map((e) => List<String>.from(e))
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
        String to = data[1];
        String ciphertext = data[2];
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
        Share.share(uri.toString());
        break;
      case 'shareToRooms':
        Identity identity = Get.find<HomeController>().getSelectedIdentity();
        RoomUtil.forwardTextMessage(identity, uri.toString());
        break;
      case 'refresh':
        tc.webViewController?.reload();
        break;
      case 'bookmark':
        var exist = await DBProvider.database.browserBookmarks
            .filter()
            .urlEqualTo(uri.toString())
            .findFirst();
        if (exist == null) {
          String? favicon = await controller
              .getFavicon(tc.webViewController!, uri.host)
              .timeout(const Duration(seconds: 10));
          String siteTitle = await tc.webViewController?.getTitle() ?? title;
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
          String siteTitle = await tc.webViewController?.getTitle() ?? title;
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
        tc.webViewController?.reload();
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
        tc.webViewController?.reload();
        break;
    }
  }

  Future onUpdateVisitedHistory(WebUri? uri) async {
    if (tc.webViewController == null) return;

    bool? canGoBack = await tc.webViewController?.canGoBack();
    bool? canGoForward = await tc.webViewController?.canGoForward();
    logger.d('canGoBack: $canGoBack, canGoForward: $canGoForward');
    tc.canGoBack.value = canGoBack ?? false;
    tc.canGoForward.value = canGoForward ?? false;
    String? newTitle = await tc.webViewController?.getTitle();
    String? favicon =
        await controller.getFavicon(tc.webViewController!, uri!.host);
    updateTabInfo(widget.uniqueKey, url, newTitle ?? title, favicon);
    controller.addHistory(uri.toString(), newTitle ?? title, favicon);
  }

  updateTabInfo(String key, String url0, String title0, String? favicon0) {
    controller.setTabData(
        uniqueId: widget.uniqueKey,
        title: title0,
        url: url0,
        favicon: favicon0);
    setState(() {
      title = title0;
      favicon = favicon0;
      url = url0;
    });
  }
}
