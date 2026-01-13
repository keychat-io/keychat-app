import 'dart:async';
import 'dart:collection' show UnmodifiableListView;
import 'dart:convert' show base64, jsonDecode;
import 'dart:io';
import 'dart:math' show Random;

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
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/nostr-core/nostr.dart';
import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/page/browser/BookmarkEdit.dart';
import 'package:keychat/page/browser/BrowserNewTab.dart';
import 'package:keychat/page/browser/BrowserTabController.dart';
import 'package:keychat/page/browser/DownloadManager_page.dart';
import 'package:keychat/page/browser/FavoriteEdit.dart';
import 'package:keychat/page/browser/MultiWebviewController.dart';
import 'package:keychat/page/browser/SelectIdentityForBrowser.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/service/SignerService.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/qrscan.service.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class WebviewTab extends StatefulWidget {
  const WebviewTab({
    required this.windowId,
    required this.uniqueKey,
    required this.initUrl,
    super.key,
    this.isCache,
    this.initTitle,
    this.keepAlive,
  });
  final String uniqueKey;
  final String initUrl;
  final String? initTitle;
  final int windowId;
  final InAppWebViewKeepAlive? keepAlive;
  final bool? isCache;
  @override
  _WebviewTabState createState() => _WebviewTabState();
}

class _WebviewTabState extends State<WebviewTab> {
  late EcashController ecashController;
  late MultiWebviewController multiWebviewController;
  late WebviewTabController tabController;
  bool pageFailed = false;
  late String initDomain;
  PullToRefreshController? pullToRefreshController;

  // Add scroll position tracking
  Map<String, Map<String, dynamic>> urlScrollPositions = {};
  bool needRestorePosition = false;

  // Track last successfully committed main-frame URL to detect downgrade loops
  WebUri? _lastCommittedMainFrameUrl;

  // Add tooltip key
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  // Add MenuController for managing menu state
  final MenuController _menuController = MenuController();

  @override
  void initState() {
    multiWebviewController = Get.find<MultiWebviewController>();
    tabController = multiWebviewController.getOrCreateController(
      widget.initUrl,
      widget.initTitle,
      widget.uniqueKey,
    );
    ecashController = Get.find<EcashController>();
    initDomain = WebUri(widget.initUrl).host;

    initBrowserConnect(WebUri(widget.initUrl));
    initPullToRefreshController();

    // Show tooltip after widget is built
    if (GetPlatform.isMobile && multiWebviewController.browserConfig.showFAB) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (multiWebviewController.browserConfig.showMiniAppTooltip) {
          _tooltipKey.currentState?.ensureTooltipVisible();
        }
      });
    }

    super.initState();
  }

  Future<void> menuOpened() async {
    if (GetPlatform.isMobile) {
      await HapticFeedback.lightImpact();
    }
    final uri = await getCurrentUrl();
    initBrowserConnect(uri);
    multiWebviewController.updateTabData(
      uniqueId: widget.uniqueKey,
      url: uri.toString(),
    );
  }

  void initBrowserConnect(WebUri uri) {
    BrowserConnect.getByHost(uri.host).then((value) {
      tabController.setBrowserConnect(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initUrl == KeychatGlobal.newTab) return const BrowserNewTab();

    return Obx(
      () => PopScope(
        canPop: !tabController.canGoBack.value,
        onPopInvokedWithResult: (didPop, d) {
          if (didPop) return;
          goBackOrPop();
        },
        child: Scaffold(
          appBar:
              GetPlatform.isDesktop ||
                  !multiWebviewController.browserConfig.showFAB
              ? AppBar(
                  titleSpacing: 0,
                  leadingWidth: 16,
                  toolbarHeight: GetPlatform.isDesktop ? 48 : 40,
                  leading: Container(),
                  centerTitle: true,
                  title: GetPlatform.isDesktop
                      ? Row(
                          spacing: 8,
                          children: [
                            Obx(
                              () => Row(
                                children: [
                                  IconButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    onPressed: tabController.canGoBack.value
                                        ? goBackOrPop
                                        : null,
                                    icon: const Icon(Icons.arrow_back),
                                  ),
                                  IconButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    onPressed: () {
                                      multiWebviewController.removeTab(
                                        widget.uniqueKey,
                                      );
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                                  IconButton(
                                    onPressed: tabController.canGoForward.value
                                        ? () async {
                                            await tabController
                                                .inAppWebViewController
                                                ?.goForward();
                                          }
                                        : null,
                                    icon: const Icon(Icons.arrow_forward),
                                  ),
                                  IconButton(
                                    onPressed: refreshPage,
                                    icon: const Icon(Icons.refresh),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: AutoSizeText(
                                  multiWebviewController.removeHttpPrefix(
                                    tabController.title.value.isEmpty
                                        ? tabController.url.value
                                        : tabController.title.value,
                                  ),
                                  minFontSize: 10,
                                  stepGranularity: 2,
                                  maxFontSize: 16,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                            ),
                          ],
                        )
                      : AutoSizeText(
                          multiWebviewController.removeHttpPrefix(
                            tabController.title.value.isEmpty
                                ? tabController.url.value
                                : tabController.title.value,
                          ),
                          minFontSize: 10,
                          stepGranularity: 2,
                          maxFontSize: 16,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                  actions: [
                    popMenu(child: const Icon(Icons.more_horiz)),
                    if (GetPlatform.isMobile)
                      IconButton(
                        onPressed: closeTab,
                        icon: SvgPicture.asset(
                          'assets/images/miniapp-exit.svg',
                          height: 28,
                          width: 28,
                          colorFilter: ColorFilter.mode(
                            Theme.of(context).iconTheme.color!,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                  ],
                )
              : null,
          floatingActionButton:
              GetPlatform.isMobile &&
                  multiWebviewController.browserConfig.showFAB
              ? Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.of(context).size.height *
                            multiWebviewController.browserConfig.fabHeight -
                        kToolbarHeight,
                  ),
                  child: Tooltip(
                    key: _tooltipKey,
                    message: 'Long-Press to close mini app',
                    showDuration: const Duration(seconds: 3),
                    waitDuration: Duration.zero,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    child: GestureDetector(
                      onLongPress: () async {
                        await multiWebviewController.browserConfig
                            .hideTooltipPermanently();
                        await HapticFeedback.mediumImpact();
                        await closeTab();
                      },
                      child: Opacity(
                        opacity: 0.7,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[800],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[400],
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white70,
                                ),
                                child: popMenu(
                                  tooltip: '',
                                  child: const Icon(
                                    CupertinoIcons.circle_fill,
                                    size: 18,
                                    color: Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
          floatingActionButtonLocation:
              multiWebviewController.browserConfig.fabPosition == 'left'
              ? FloatingActionButtonLocation.miniStartFloat
              : FloatingActionButtonLocation.miniEndFloat,
          body: SafeArea(
            bottom:
                GetPlatform.isAndroid ||
                multiWebviewController.bottomSafeHosts.contains(
                  WebUri(widget.initUrl).host,
                ),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      _getWebview(),
                      Obx(
                        () => tabController.progress.value < 1.0
                            ? LinearProgressIndicator(
                                value: tabController.progress.value < 0.1
                                    ? 0.1
                                    : tabController.progress.value,
                              )
                            : Container(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget popMenu({required Widget child, String? tooltip}) {
    // Mobile: use bottomSheet
    if (GetPlatform.isMobile) {
      return IconButton(
        tooltip: tooltip,
        onPressed: () async {
          unawaited(
            multiWebviewController.browserConfig.hideTooltipPermanently(),
          );
          await menuOpened();
          await _showMobileBottomSheet();
        },
        icon: child,
      );
    }

    // Desktop: use MenuAnchor
    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        elevation: WidgetStateProperty.all(8),
        backgroundColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.surface,
        ),
      ),
      menuChildren: _buildDesktopMenuItems(),
      onOpen: () async {
        await menuOpened();
      },
      onClose: () {
        logger.d('popup menu closed');
      },
      builder: (context, controller, child) {
        return IconButton(
          tooltip: tooltip,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: child!,
        );
      },
      child: child,
    );
  }

  Future<void> _showMobileBottomSheet() async {
    await Get.bottomSheet<void>(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      Scaffold(
        body: SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Tools section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: getPopTools(isBottomSheet: true),
                  ),
                  const Divider(height: 1),
                  // Menu items
                  ..._buildMobileMenuItems(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDesktopMenuItems() {
    return [
      SizedBox(
        width: 280,
        child: getPopTools(),
      ),
      MenuItemButton(
        onPressed: () => _handleMenuSelection('bookmark'),
        child: Row(
          spacing: 16,
          children: [
            FutureBuilder(
              future: () async {
                final url = await tabController.inAppWebViewController
                    ?.getUrl();
                if (url == null) return null;
                return DBProvider.database.browserBookmarks
                    .filter()
                    .urlEqualTo(url.toString())
                    .findFirst();
              }(),
              builder: (context, snapshot) {
                if (snapshot.data != null) {
                  return const Icon(
                    CupertinoIcons.bookmark_fill,
                    color: Colors.orange,
                  );
                }
                return Icon(
                  CupertinoIcons.bookmark,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                );
              },
            ),
            Text(
              'Bookmark',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
      MenuItemButton(
        onPressed: () => _handleMenuSelection('favorite'),
        child: Row(
          spacing: 16,
          children: [
            SvgPicture.asset(
              'assets/images/app_add.svg',
              height: 24,
              width: 24,
              colorFilter: ColorFilter.mode(
                Theme.of(context).iconTheme.color!.withAlpha(200),
                BlendMode.srcIn,
              ),
            ),
            Text(
              'Add to Favorites',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      MenuItemButton(
        onPressed: () => _handleMenuSelection('shareToRooms'),
        child: Row(
          spacing: 16,
          children: [
            Icon(
              CupertinoIcons.chat_bubble,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            Text(
              'Share to Room',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),

      MenuItemButton(
        onPressed: () => _handleMenuSelection('zoom'),
        child: Row(
          spacing: 16,
          children: [
            Icon(
              CupertinoIcons.zoom_in,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            Text(
              'Zoom Text',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
      if (tabController.browserConnect.value.host == '')
        MenuItemButton(
          onPressed: () => _handleMenuSelection('clear'),
          child: Row(
            spacing: 12,
            children: [
              Icon(
                Icons.storage,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              Text(
                'ID Logout',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      const Divider(height: 1),
      if (tabController.browserConnect.value.host != '')
        MenuItemButton(
          onPressed: () => _handleMenuSelection('clear'),
          child: Row(
            spacing: 12,
            children: [
              Icon(
                Icons.logout,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              Text(
                'ID Logout',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _buildMobileMenuItems() {
    return [
      _buildMobileMenuItem(
        icon: CupertinoIcons.bookmark,
        activeIcon: CupertinoIcons.bookmark_fill,
        label: 'Bookmark',
        onTap: () => _handleMobileMenuSelection('bookmark'),
        checkActive: () async {
          final url = await tabController.inAppWebViewController?.getUrl();
          if (url == null) return false;
          final exist = await DBProvider.database.browserBookmarks
              .filter()
              .urlEqualTo(url.toString())
              .findFirst();
          return exist != null;
        },
      ),
      _buildMobileMenuItem(
        icon: Icons.add_circle_outline,
        label: 'Add to Favorites',
        onTap: () => _handleMobileMenuSelection('favorite'),
      ),
      _buildMobileMenuItem(
        icon: CupertinoIcons.chat_bubble,
        label: 'Share to Room',
        onTap: () => _handleMobileMenuSelection('shareToRooms'),
      ),
      _buildMobileMenuItem(
        icon: CupertinoIcons.zoom_in,
        label: 'Zoom Text',
        onTap: () => _handleMobileMenuSelection('zoom'),
      ),
      _buildKeepAliveMenuItemMobile(),
      _buildMobileMenuItem(
        icon: Icons.storage,
        label: 'ID Logout',
        onTap: () => _handleMobileMenuSelection('clear'),
      ),
    ];
  }

  Widget _buildMobileMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    IconData? activeIcon,
    Future<bool> Function()? checkActive,
  }) {
    return ListTile(
      leading: checkActive != null
          ? FutureBuilder<bool>(
              future: checkActive(),
              builder: (context, snapshot) {
                if ((snapshot.data ?? false) && activeIcon != null) {
                  return Icon(activeIcon, color: Colors.orange);
                }
                return Icon(icon);
              },
            )
          : Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }

  Widget _buildKeepAliveMenuItemMobile() {
    return ListTile(
      leading: const Icon(Icons.autorenew),
      title: const Text('Keep Alive'),
      trailing: Transform.scale(
        scale: 0.8,
        child: FutureBuilder(
          future: (() async {
            await multiWebviewController.loadKeepAlive();
          })(),
          builder: (context, snapshot) {
            return Switch(
              value: multiWebviewController.mobileKeepAlive.keys.contains(
                initDomain,
              ),
              onChanged: (value) async {
                Get.back<void>();
                if (value) {
                  await multiWebviewController.enableKeepAlive(initDomain);
                  EasyLoading.showSuccess(
                    'KeepAlive Enabled. Take effect after restarting the page.',
                  );
                  return;
                }
                await multiWebviewController.disableKeepAlive(initDomain);
                EasyLoading.showSuccess(
                  'KeepAlive Disabled.',
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleMobileMenuSelection(String value) async {
    Get.back<void>();
    await popupMenuSelected(value);
  }

  Future<void> _handleMenuSelection(String value) async {
    _menuController.close();
    await popupMenuSelected(value);
  }

  Widget _getWebview() {
    return Obx(
      () => InAppWebView(
        key: tabController.pageStorageKey.value,
        keepAlive: GetPlatform.isDesktop ? null : widget.keepAlive,
        webViewEnvironment: multiWebviewController.webViewEnvironment,
        initialUrlRequest: URLRequest(url: WebUri(tabController.url.value)),
        initialSettings: tabController.settings,
        pullToRefreshController: pullToRefreshController,
        initialUserScripts: UnmodifiableListView([
          multiWebviewController.textSizeUserScript,
        ]),
        onScrollChanged: (controller, x, y) async {
          // Save scroll position by current URL
          if (GetPlatform.isAndroid) {
            EasyDebounce.debounce(
              'saveScroll:${tabController.url.value}',
              const Duration(milliseconds: 500),
              () async {
                final uri = await controller.getUrl();
                if (uri == null) return;
                final currentUrl = uri.toString();
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
                final urlString = createWindowAction.request.url.toString();

                // Check for special URLs first
                handleSpecialUrls(urlString).then((handled) {
                  if (handled) return;
                  // If not a special URL, create new window
                  multiWebviewController.launchWebview(initUrl: urlString);
                });
                return true;
              }
            : null,
        onWebViewCreated: (controller) async {
          logger.d('onWebViewCreated ${widget.initUrl}');

          // load from keepalive state; hide the progress bar
          if (widget.isCache ?? false) {
            tabController.progress.value = 1.0;
          }
          tabController.setWebViewController(controller, widget.initUrl);
          await controller.evaluateJavascript(
            source: '''
                        window.print = function(){};
                      ''',
          );

          controller
            ..addJavaScriptHandler(
              handlerName: 'keychat-nostr',
              callback: javascriptHandlerNostr,
            )
            ..addJavaScriptHandler(
              handlerName: 'keychat-webln',
              callback: javascriptHandlerWebLN,
            );
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
          if (GetPlatform.isDesktop) {
            return PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.GRANT,
            );
          }
          final resources = <PermissionResourceType>[];

          for (final resource in request.resources) {
            var granted = false;

            // Check if permission is camera or microphone
            if (resource == PermissionResourceType.CAMERA) {
              final status = await Permission.camera.request();
              granted = status.isGranted;
            } else if (resource == PermissionResourceType.MICROPHONE) {
              final status = await Permission.microphone.request();
              granted = status.isGranted;
            } else {
              // For other permissions, grant by default
              granted = true;
            }

            if (granted) {
              resources.add(resource);
            }
          }

          return PermissionResponse(
            resources: resources,
            action: resources.isEmpty
                ? PermissionResponseAction.DENY
                : PermissionResponseAction.GRANT,
          );
        },
        shouldOverrideUrlLoading: (controller, NavigationAction navigationAction) async {
          final uri = navigationAction.request.url;
          logger.i('shouldOverrideUrlLoading: $uri');
          if (uri == null) return NavigationActionPolicy.ALLOW;
          // Detect https->http downgrade loop for same host (main frame only)
          if (navigationAction.isForMainFrame &&
              _lastCommittedMainFrameUrl != null &&
              _lastCommittedMainFrameUrl!.scheme == 'https' &&
              uri.scheme == 'http' &&
              uri.host == _lastCommittedMainFrameUrl!.host) {
            logger.w(
              'Blocked downgrade navigation (https -> http) for host ${uri.host}',
            );
            return NavigationActionPolicy.CANCEL;
          }
          // download file

          if (uri.toString().startsWith('blob:')) {
            await EasyLoading.showError('Blob files are not supported');
            return NavigationActionPolicy.CANCEL;
          }
          if (navigationAction.shouldPerformDownload ?? false) {
            return NavigationActionPolicy.DOWNLOAD;
          }

          try {
            final str = uri.toString();

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
                urlRequest: URLRequest(
                  url: WebUri.uri(Uri.parse(googleDocsUrl)),
                ),
              );
              return NavigationActionPolicy.CANCEL;
            }

            if ([
              'http',
              'https',
              'data',
              'javascript',
              'about',
            ].contains(uri.scheme)) {
              return NavigationActionPolicy.ALLOW;
            }
            try {
              await launchUrl(uri);
            } catch (e) {
              if (e is PlatformException) {
                await EasyLoading.showError(
                  'Failed to open link: ${e.message}',
                );
                return NavigationActionPolicy.CANCEL;
              }
              logger.i(e.toString(), error: e);
              await EasyLoading.showError('Failed to open link: $e');
            }
          } catch (e) {
            logger.i(e.toString(), error: e);
          }
          return NavigationActionPolicy.CANCEL;
        },
        onLoadStop: (controller, url) async {
          if (url == null) return;
          logger.d('onLoadStop: $url');
          // Store last committed main-frame URL (used for downgrade loop detection)
          _lastCommittedMainFrameUrl = url;
          await _checkGoBackState(url.toString());
          await controller.injectJavascriptFileFromAsset(
            assetFilePath: 'assets/js/nostr.js',
          );
          await controller.injectJavascriptFileFromAsset(
            assetFilePath: 'assets/js/webln.js',
          );
          pullToRefreshController?.endRefreshing();
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
          logger.i('onPageCommitVisible: $url');
        },
        onRenderProcessGone: (controller, detail) {
          logger.i('onRenderProcessGone: $detail');
          unawaited(refreshPage());
        },
        onReceivedServerTrustAuthRequest: (_, challenge) async {
          final sslError = challenge.protectionSpace.sslError;
          logger.i(
            'onReceivedServerTrustAuthRequest: ${challenge.protectionSpace.host} ${sslError?.code}',
          );

          return ServerTrustAuthResponse(
            action: ServerTrustAuthResponseAction.PROCEED,
          );
        },
        onReceivedHttpError: (controller, request, error) async {
          logger.i('onReceivedHttpError: ${request.url} ${error.statusCode}');
        },
        onDidReceiveServerRedirectForProvisionalNavigation: (controller) async {
          logger.i(
            'onDidReceiveServerRedirectForProvisionalNavigation: ${await controller.getUrl()}',
          );
          // return ServerRedirectAction.ALLOW;
        },
        onReceivedClientCertRequest: (controller, challenge) {
          logger.i(
            'onReceivedClientCertRequest: ${challenge.protectionSpace.host}',
          );
          return ClientCertResponse(action: ClientCertResponseAction.PROCEED);
        },
        onProgressChanged: (controller, data) async {
          if (data == 100) {
            await pullToRefreshController?.endRefreshing();
          }
          tabController.progress.value = data / 100;
        },
        onWebContentProcessDidTerminate: (controller) {
          logger.i('onWebContentProcessDidTerminate: ${controller.hashCode}');
          unawaited(refreshPage());
        },
        onReceivedError:
            (
              InAppWebViewController controller,
              WebResourceRequest request,
              error,
            ) async {
              final url = request.url.toString();
              logger.i(
                'onReceivedError: $url ${error.type} ${error.description}',
              );
              final isForMainFrame = request.isForMainFrame ?? false;
              final isCancel = error.type == WebResourceErrorType.CANCELLED;
              if (!isForMainFrame || isCancel) {
                return;
              }
              pullToRefreshController?.endRefreshing();
              if (error.description.contains(
                'domain=WebKitErrorDomain, code=102',
              )) {
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

              final errorUrl = request.url;
              pageFailed = true;
              await tabController.inAppWebViewController?.loadData(
                data:
                    '''
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
    ''',
                baseUrl: errorUrl,
                historyUrl: WebUri(widget.initUrl),
              );
              await _checkGoBackState(url);
            },
        onConsoleMessage: (controller, consoleMessage) {
          if (kDebugMode) {
            print('console: ${consoleMessage.message}');
          }
        },
        onTitleChanged: (controller, title) async {
          if (title == null) return;
          final uri = await getCurrentUrl();
          updateTabInfo(widget.uniqueKey, uri.toString(), title);
        },
        onUpdateVisitedHistory: (controller, url, androidIsReload) async {
          // logger.i('onUpdateVisitedHistory: ${url.toString()} $androidIsReload');
          await onUpdateVisitedHistory(url);
        },
        onDownloadStarting: (controller, request) async {
          logger.d('onDownloadStart $request');
          await downloadFile(request);
          return DownloadStartResponse(handled: true);
        },
      ),
    );
  }

  Future<void> closeTab() async {
    if (pageFailed) {
      multiWebviewController.removeKeepAlive(widget.initUrl);
    }
    if (Get.isBottomSheetOpen ?? false) {
      Get.back<void>();
    }
    await pausePlayingMedia();
    Get.back<void>(); // exit page
  }

  // Add method to restore scroll position
  Future<void> restoreScrollPosition(String url) async {
    if (tabController.inAppWebViewController == null || url.isEmpty) return;

    final savedPosition = urlScrollPositions[url];
    if (savedPosition != null) {
      try {
        // Wait for page to load before scrolling
        await Future.delayed(const Duration(milliseconds: 500));

        await tabController.inAppWebViewController!.scrollTo(
          x: savedPosition['scrollX'] ?? 0,
          y: savedPosition['scrollY'] ?? 0,
        );
      } catch (e) {
        logger.e('Failed to restore scroll position: $e');
      }
    }
  }

  Future<WebUri> _getCurrentUriTimeOut() async {
    final completer = Completer<WebUri>();
    Timer? timeoutTimer;
    var isCompleted = false;

    try {
      if (tabController.inAppWebViewController == null) {
        throw Exception('WebViewController is null');
      }

      timeoutTimer = Timer(const Duration(seconds: 2), () {
        if (!isCompleted) {
          isCompleted = true;
          if (!completer.isCompleted) {
            completer.completeError(
              TimeoutException('Get URL timeout after 2 seconds'),
            );
          }
        }
      });
      final uri = await tabController.inAppWebViewController!.getUrl();

      if (!isCompleted) {
        isCompleted = true;
        timeoutTimer.cancel();
        if (uri != null) {
          if (!completer.isCompleted) {
            completer.complete(uri);
          }
        } else {
          if (!completer.isCompleted) {
            completer.completeError(Exception('URL is null'));
          }
        }
      }

      return await completer.future;
    } catch (e) {
      if (!isCompleted) {
        isCompleted = true;
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
      rethrow;
    } finally {
      timeoutTimer?.cancel();
    }
  }

  WebUri? lastViewUri;
  Future<WebUri> getCurrentUrl() async {
    try {
      final uri = await _getCurrentUriTimeOut();
      setState(() {
        lastViewUri = uri;
      });
      return uri;
    } catch (e) {
      await refreshPage();
      return WebUri.uri(Uri.parse(widget.initUrl));
    }
  }

  Widget getPopTools({bool isBottomSheet = false}) {
    void closeMenu() {
      if (isBottomSheet) {
        Get.back<void>();
      } else {
        _menuController.close();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      constraints: BoxConstraints(
        maxWidth: isBottomSheet ? double.infinity : 280,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lastViewUri?.toString() ?? tabController.url.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildToolButton(
                icon: Icons.refresh,
                label: 'Refresh',
                color: Colors.blue,
                onPressed: () async {
                  closeMenu();
                  await refreshPage();
                },
              ),
              _buildToolButton(
                icon: Icons.copy,
                label: 'Copy',
                color: Colors.green,
                onPressed: () async {
                  final uri = await getCurrentUrl();
                  await Clipboard.setData(ClipboardData(text: uri.toString()));
                  await EasyLoading.showToast('URL Copied');
                },
              ),
              _buildToolButton(
                icon: Icons.share,
                label: 'Share',
                color: Colors.orange,
                onPressed: () async {
                  closeMenu();
                  final uri = await getCurrentUrl();
                  await SharePlus.instance.share(ShareParams(uri: uri));
                },
              ),
              _buildToolButton(
                icon: Icons.file_download,
                label: 'Download',
                color: Colors.purple,
                onPressed: () async {
                  closeMenu();
                  await Get.to<void>(() => const DownloadManagerPage());
                },
              ),
              if (GetPlatform.isMobile)
                _buildToolButton(
                  icon: Icons.exit_to_app,
                  label: 'Exit',
                  color: Colors.redAccent,
                  onPressed: () async {
                    await _handleMobileMenuSelection('close');
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  void goBackOrPop() {
    tabController.inAppWebViewController?.canGoBack().then((canGoBack) async {
      logger.i('goBackOrPop: canGoBack: $canGoBack');
      if (canGoBack) {
        await pausePlayingMedia();
        await tabController.inAppWebViewController?.goBack();
        return;
      }
      if (GetPlatform.isDesktop) {
        return;
      }
      if (pageFailed) {
        multiWebviewController.removeKeepAlive(widget.initUrl);
      }
      await pausePlayingMedia();
      Get.back<void>();
    });
  }

  // info coming from the JavaScript side!
  Future<Object?>? javascriptHandlerNostr(List<dynamic> data) async {
    logger.i('javascriptHandler: $data');
    final method = data[0] as String;
    if (method == 'getRelays') {
      final relays = await RelayService.instance.getEnableList();
      return relays;
    }

    if (method == 'pageFailedToRefresh') {
      await refreshPage();
      return null;
    }

    if (method == 'blobFileDownload') {
      _downloadBlob(data[1], data[2]);
      return null;
    }

    final host = (await getCurrentUrl()).host;
    final skipCache = method == 'getPublicKey';
    final identity = await getOrSelectIdentity(host, skipCache: skipCache);
    if (identity == null) {
      return null;
    }

    logger.i('selected: ${identity.secp256k1PKHex}');
    switch (method) {
      case 'getPublicKey':
        return identity.secp256k1PKHex;
      case 'onAccountChanged':
        await switchAccountFromMiniApp(host, data[1] as String);
        return null;
      case 'signEvent':
        final event = data[1] as Map<String, dynamic>;

        // Confirm signing event
        if (!multiWebviewController.browserConfig.autoSignEvent) {
          try {
            final confirm = await Get.bottomSheet<bool>(
              signEventConfirm(
                content: event['content'] as String,
                kind: event['kind'] as int,
                tags: (event['tags'] as List)
                    .map(
                      (e) =>
                          List<String>.from(e.map((item) => item.toString())),
                    )
                    .toList(),
              ),
            );
            if (confirm == null || !confirm) {
              return null;
            }
          } catch (e, s) {
            logger.e('Failed to parse event: $event', stackTrace: s);
            return null;
          }
        }
        final res = await NostrAPI.instance.signEventByIdentity(
          identity: identity,
          content: event['content'] as String,
          createdAt: event['created_at'] as int,
          kind: event['kind'] as int,
          tags: (event['tags'] as List)
              .map((e) => List<String>.from(e.map((item) => item.toString())))
              .toList(),
        );

        return res;
      case 'nip04Encrypt':
        final to = data[1] as String;
        final plaintext = data[2] as String;
        if (identity.isFromSigner) {
          final ciphertext = await SignerService.instance.nip04Encrypt(
            plaintext: plaintext,
            currentUser: identity.secp256k1PKHex,
            to: to,
          );
          return ciphertext;
        }
        final encryptedEvent = await rust_nostr.getEncryptEvent(
          senderKeys: await identity.getSecp256k1SKHex(),
          receiverPubkey: to,
          content: plaintext,
        );
        final model = NostrEventModel.fromJson(jsonDecode(encryptedEvent));
        return model.content;
      case 'nip04Decrypt':
        final from = data[1] as String;
        final ciphertext = data[2] as String;
        if (identity.isFromSigner) {
          final plaintext = await SignerService.instance.nip04Decrypt(
            ciphertext: ciphertext,
            currentUser: identity.secp256k1PKHex,
            from: from,
          );
          return plaintext;
        }
        final content = await rust_nostr.decrypt(
          senderKeys: await identity.getSecp256k1SKHex(),
          receiverPubkey: from,
          content: ciphertext,
        );
        return content;
      case 'nip44Encrypt':
        final to = data[1] as String;
        final plaintext = data[2] as String;
        String ciphertext;
        if (identity.isFromSigner) {
          ciphertext = await SignerService.instance.nip44Encrypt(
            plaintext,
            to,
            identity.secp256k1PKHex,
          );
        } else {
          ciphertext = await rust_nostr.encryptNip44(
            senderKeys: await identity.getSecp256k1SKHex(),
            receiverPubkey: to,
            content: plaintext,
          );
        }
        return ciphertext;
      case 'nip44Decrypt':
        final to = data[1] as String;
        final ciphertext = data[2] as String;
        if (identity.isFromSigner) {
          final plaintext = await SignerService.instance.nip44Decrypt(
            ciphertext,
            to,
            identity.secp256k1PKHex,
          );
          return plaintext;
        }
        return rust_nostr.decryptNip44(
          secretKey: await identity.getSecp256k1SKHex(),
          publicKey: to,
          content: ciphertext,
        );
      default:
    }
    // return data to the JavaScript side!
    return 'Error: not implemented';
  }

  Future<void> switchAccountFromMiniApp(String host, String publicKey) async {
    final identity = await IdentityService.instance.getIdentityByNostrPubkey(
      publicKey,
    );
    if (identity == null) {
      await EasyLoading.showError('Identity not found for pubkey: $publicKey');
      return;
    }
    final bc = await BrowserConnect.getByHost(host);
    if (bc != null) {
      await BrowserConnect.delete(bc.id);
    }

    final favicon = await multiWebviewController.getFavicon(
      tabController.inAppWebViewController!,
      host,
    );

    final model = BrowserConnect(
      host: host,
      pubkey: publicKey,
    )..favicon = favicon;
    await BrowserConnect.save(model);
    tabController.setBrowserConnect(model);
  }

  Future<Identity?> getOrSelectIdentity(
    String host, {
    bool skipCache = false,
  }) async {
    var bc = await BrowserConnect.getByHost(host);
    if (bc != null && !skipCache) {
      final identity = await IdentityService.instance.getIdentityByNostrPubkey(
        bc.pubkey,
      );
      if (identity != null) {
        return identity;
      }
      await BrowserConnect.delete(bc.id);
    }
    if (Get.isBottomSheetOpen ?? false) {
      return null;
    }
    // select a identity
    final selected = await Get.bottomSheet<Identity>(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      SelectIdentityForBrowser(host),
    );
    if (selected != null) {
      EasyLoading.show(status: 'Processing...');
      try {
        final favicon = await multiWebviewController.getFavicon(
          tabController.inAppWebViewController!,
          host,
        );

        bc ??= BrowserConnect(
          host: host,
          pubkey: selected.secp256k1PKHex,
        );

        bc
          ..pubkey = selected.secp256k1PKHex
          ..favicon = favicon;
        final id = await BrowserConnect.save(bc);
        bc.id = id;
        tabController.setBrowserConnect(bc);
        await EasyLoading.dismiss();
      } catch (e, s) {
        logger.e(e.toString(), stackTrace: s);
        await EasyLoading.showError(e.toString());
      }
    }
    return selected;
  }

  Future<void> popupMenuSelected(String value) async {
    final currentUri = await getCurrentUrl();
    switch (value) {
      case 'share':
        await SharePlus.instance.share(ShareParams(uri: currentUri));
      case 'shareToRooms':
        final identity = Get.find<HomeController>().getSelectedIdentity();
        await RoomUtil.forwardTextMessage(identity, currentUri.toString());
      case 'refresh':
        await refreshPage();
      case 'bookmark':
        final exist = await DBProvider.database.browserBookmarks
            .filter()
            .urlEqualTo(currentUri.toString())
            .findFirst();
        if (exist == null) {
          logger.i('add bookmark: $currentUri');
          final favicon = await multiWebviewController.getFavicon(
            tabController.inAppWebViewController!,
            currentUri.host,
          );
          final siteTitle = await tabController.inAppWebViewController
              ?.getTitle();
          await BrowserBookmark.add(
            url: currentUri.toString(),
            favicon: favicon,
            title: siteTitle,
          );
          EasyLoading.showSuccess('Added');
        } else {
          await Get.to(() => BookmarkEdit(model: exist));
        }
      case 'favorite':
        final exist = await BrowserFavorite.getByUrl(currentUri.toString());
        if (exist == null) {
          final favicon = await multiWebviewController.getFavicon(
            tabController.inAppWebViewController!,
            currentUri.host,
          );
          final siteTitle = await tabController.inAppWebViewController
              ?.getTitle();
          await BrowserFavorite.add(
            url: currentUri.toString(),
            favicon: favicon,
            title: siteTitle,
          );
          EasyLoading.showSuccess('Added');
        } else {
          await Get.to(() => FavoriteEdit(favorite: exist));
        }
        await multiWebviewController.loadFavorite();
      case 'copy':
        Clipboard.setData(ClipboardData(text: currentUri.toString()));
        EasyLoading.showToast('Copied');
      case 'clear':
        final res = await BrowserConnect.getByHost(currentUri.host);
        if (res != null) {
          await BrowserConnect.delete(res.id);
        }
        await tabController.inAppWebViewController?.webStorage.localStorage
            .clear();
        await tabController.inAppWebViewController?.webStorage.sessionStorage
            .clear();
        var domain = currentUri.host;
        // Extract main domain (remove subdomain)
        if (domain.split('.').length > 2) {
          domain = domain.split('.').sublist(1).join('.');
        }
        logger.d('currentUri: $domain');
        await CookieManager.instance().deleteCookies(
          url: WebUri(currentUri.toString()),
          domain: currentUri.host,
          webViewController: tabController.inAppWebViewController,
        );
        await CookieManager.instance().deleteCookies(
          url: WebUri(currentUri.toString()),
          domain: '.$domain',
          webViewController: tabController.inAppWebViewController,
        );
        EasyLoading.showToast('Logout Success');

        tabController.setBrowserConnect(null);
        tabController.canGoBack.value = false;
        tabController.canGoForward.value = false;
        await refreshPage();
      case 'close':
        await closeTab();
      case 'downloads':
        await Get.to<void>(() => const DownloadManagerPage());
      case 'zoom':
        Get.bottomSheet(
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
          SafeArea(
            child: Scaffold(
              appBar: AppBar(title: const Text('Zoom Text')),
              body: Container(
                padding: const EdgeInsets.all(16),
                child: Obx(
                  () => Slider(
                    value: double.parse(
                      multiWebviewController.kInitialTextSize.value.toString(),
                    ),
                    min: 50,
                    max: 300,
                    divisions: 10,
                    label: '${multiWebviewController.kInitialTextSize.value}',
                    onChanged: (value) async {
                      await tabController.updateTextSize(value.toInt());
                    },
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }

  Future<void> onUpdateVisitedHistory(WebUri? uri) async {
    if (tabController.inAppWebViewController == null || uri == null) return;
    EasyDebounce.debounce(
      'onUpdateVisitedHistory:$uri',
      const Duration(milliseconds: 200),
      () async {
        await _checkGoBackState(uri.toString());
        if (uri.toString() == 'about:blank') {
          return;
        }
        final newTitle = await tabController.inAppWebViewController?.getTitle();
        var title = newTitle ?? tabController.title.value;
        if (title.isEmpty) {
          title = tabController.title.value;
        }
        updateTabInfo(widget.uniqueKey, uri.toString(), title);
        await multiWebviewController.addHistory(uri.toString(), title);
        await multiWebviewController
            .getFavicon(tabController.inAppWebViewController!, uri.host)
            .then((favicon) {
              if (favicon != null && tabController.favicon != favicon) {
                tabController.favicon = favicon;
                multiWebviewController.setTabDataFavicon(
                  uniqueId: widget.uniqueKey,
                  favicon: favicon,
                );
              }
            });
      },
    );
  }

  Future<void> _checkGoBackState(String url) async {
    final canGoBack = await tabController.inAppWebViewController?.canGoBack();
    final canGoForward = await tabController.inAppWebViewController
        ?.canGoForward();
    logger.i('$url canGoBack: $canGoBack, canGoForward: $canGoForward');
    tabController.canGoBack.value = canGoBack ?? false;
    tabController.canGoForward.value = canGoForward ?? false;
  }

  void updateTabInfo(String key, String url0, String title0) {
    // logger.i('updateTabInfo: $key, $url0, $title0');
    multiWebviewController.setTabData(
      uniqueId: widget.uniqueKey,
      title: title0,
      url: url0,
    );
    tabController.title.value = title0;
    tabController.url.value = url0;
  }

  Future<bool> downloadFile(DownloadStartRequest request) async {
    final url = request.url.toString();
    final filename = request.suggestedFilename ?? path.basename(url);

    final shouldDownload = await Get.dialog<bool>(
      CupertinoAlertDialog(
        title: const Text('Download File'),
        content: Text(
          '$filename\n\nSize: ${FileService.instance.getFileSizeDisplay(request.contentLength)}',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Get.back(result: true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (shouldDownload != true) {
      return false;
    }

    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) {
      await EasyLoading.showToast('No directory selected');
      return false;
    }

    logger.i(
      'start to download $url, save to: $selectedDirectory filename: $filename ',
    );
    await EasyLoading.showToast('Downloading...');
    final (baseDirectory, directory, filename2) = await Task.split(
      filePath: '$selectedDirectory/$filename',
    );
    final task = DownloadTask(
      url: url,
      filename: filename,
      baseDirectory: baseDirectory,
      directory: directory,
    );

    FileDownloader().download(
      task,
      onProgress: (progress) {},
      onStatus: (status) async {
        logger.i('Status: $status');
        if (status == TaskStatus.complete) {
          final shouldOpen = await Get.dialog<bool>(
            CupertinoAlertDialog(
              title: const Text('Download Complete'),
              content: Text('File saved to:\n$selectedDirectory/$filename'),
              actions: [
                CupertinoActionSheetAction(
                  onPressed: () => Get.back(result: false),
                  child: const Text('Close'),
                ),
                CupertinoActionSheetAction(
                  isDefaultAction: true,
                  onPressed: () => Get.back(result: true),
                  child: const Text('Open Folder'),
                ),
              ],
            ),
          );

          if (shouldOpen ?? false) {
            try {
              await launchUrl(Uri.file(selectedDirectory));
            } catch (e) {
              logger.e('Failed to open directory: $e');
              await EasyLoading.showError('Failed to open directory');
            }
          }
        }
      },
    );
    return true;
  }

  Future<void> _saveBlobFile(String base64String, String mimeType) async {
    try {
      if (GetPlatform.isMobile) {
        final storagePermission = await Permission.storage.request();
        if (!storagePermission.isGranted) {
          EasyLoading.showError('Storage permission not granted');
          return;
        }
      }

      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        EasyLoading.dismiss();
        return;
      }

      // Decode base64 to bytes
      final bytes = base64.decode(base64String);

      // Determine file extension from MIME type
      final extension = _getExtensionFromMimeType(mimeType);
      final filename =
          'download_${DateTime.now().millisecondsSinceEpoch}$extension';

      final filePath = path.join(selectedDirectory, filename);
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      EasyLoading.dismiss();

      final shouldOpen = await Get.dialog<bool>(
        CupertinoAlertDialog(
          title: const Text('Download Complete'),
          content: Text('File saved to:\n$filePath'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Get.back(result: false),
              child: const Text('Close'),
            ),
            CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () => Get.back(result: true),
              child: const Text('Open Folder'),
            ),
          ],
        ),
      );

      if (shouldOpen ?? false) {
        try {
          await launchUrl(Uri.file(selectedDirectory));
        } catch (e) {
          logger.e('Failed to open directory: $e');
        }
      }
    } catch (e, s) {
      logger.e('Failed to save blob file: $e', stackTrace: s);
      EasyLoading.showError('Failed to save file');
    }
  }

  String _getExtensionFromMimeType(String mimeType) {
    final mimeMap = {
      'image/png': '.png',
      'image/jpeg': '.jpg',
      'image/jpg': '.jpg',
      'image/gif': '.gif',
      'image/webp': '.webp',
      'image/svg+xml': '.svg',
      'application/pdf': '.pdf',
      'application/zip': '.zip',
      'application/x-zip-compressed': '.zip',
      'text/plain': '.txt',
      'text/html': '.html',
      'application/json': '.json',
      'video/mp4': '.mp4',
      'video/webm': '.webm',
      'audio/mpeg': '.mp3',
      'audio/wav': '.wav',
      'application/octet-stream': '.bin',
    };
    return mimeMap[mimeType.toLowerCase()] ?? '.bin';
  }

  Future<void> renderAssetAsHtml(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    final htmlContent =
        '''
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
      <img src="${request.url}" alt="Image"/>
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
    final method = data[0] as String;
    switch (method) {
      case 'getInfo':
        var identity = Get.find<EcashController>().currentIdentity;
        identity ??= Get.find<HomeController>().getSelectedIdentity();
        return {
          'node': {
            'alias': identity.displayName,
            'pubkey': identity.secp256k1PKHex,
          },
        };
      case 'signMessage':
        var identity = Get.find<EcashController>().currentIdentity;
        identity ??= Get.find<HomeController>().getSelectedIdentity();

        final message = data[1] as String;
        final signature = await rust_nostr.signSchnorr(
          privateKey: await identity.getSecp256k1SKHex(),
          content: message,
        );
        return {
          'signature': signature,
          'message': message,
        };
      case 'verifyMessage':
        var identity = Get.find<EcashController>().currentIdentity;
        identity ??= Get.find<HomeController>().getSelectedIdentity();

        final signature = data[1] as String;
        final message = data[2] as String;
        final isValid = await rust_nostr.verifySchnorr(
          pubkey: identity.secp256k1PKHex,
          content: message,
          sig: signature,
          hash: true,
        );
        return isValid;
      case 'sendPayment':
        final lnbc = data[1] as String?;
        if (lnbc == null || lnbc.isEmpty) {
          return 'Error: Invoice is empty';
        }
        try {
          final tr = await ecashController.payToLightning(
            lnbc,
            isPay: true,
          );
          if (tr == null) {
            return 'Error: Payment failed or cancelled';
          }
          return ecashController.getPreimage(tr);
        } catch (e) {
          final msg = Utils.getErrorMessage(e);
          return 'Error: - $msg';
        }
      case 'makeInvoice':
        try {
          final source = data[1] as Map? ?? {};
          final amount =
              source['amount'] != null &&
                  source['amount'] is String &&
                  (source['amount'] as String).isNotEmpty
              ? int.parse(source['amount'] as String)
              : 0;
          final defaultAmount =
              source['defaultAmount'] != null &&
                  source['defaultAmount'] is String &&
                  (source['defaultAmount'] as String).isNotEmpty
              ? int.parse(source['defaultAmount'] as String)
              : 0;
          final invoiceAmount = amount > 0 ? amount : defaultAmount;
          return EcashUtils.proccessMakeLnInvoice(
            amount: invoiceAmount,
            description: source['description'] as String? ?? '',
            getString: true,
          );
        } catch (e, s) {
          logger.e(e.toString(), stackTrace: s);
        }

      default:
    }
    return null;
  }

  Widget signEventConfirm({
    required String content,
    required int kind,
    required List<dynamic> tags,
  }) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Event')),
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
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Get.back(result: true);
                    },
                    child: const Text('Sign Event'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          color: Theme.of(
            Get.context!,
          ).colorScheme.outline.withValues(alpha: 0.2),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                Get.context!,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: Get.back,
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Show full content'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> pausePlayingMedia() async {
    try {
      await tabController.inAppWebViewController
          ?.evaluateJavascript(
            source: """
      document.querySelectorAll('audio, video').forEach(media => media.pause());
    """,
          )
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      logger.e(e.toString(), error: e);
    }
  }

  Future<void> refreshPage() async {
    EasyThrottle.throttle(
      'refreshPage${tabController.hashCode}',
      const Duration(seconds: 2),
      () async {
        await EasyLoading.dismiss();
        try {
          final uri = await _getCurrentUriTimeOut();
          logger.i('refreshPage-geturi: $uri');
          await tabController.inAppWebViewController!.loadUrl(
            urlRequest: URLRequest(url: uri),
          );
          logger.i('refreshPage-done: $uri');
        } catch (e) {
          // ⛔ A MacOSInAppWebViewController was used after being disposed.
          // ⛔ Once the MacOSInAppWebViewController has been disposed, it can no longer be used.
          tabController.url.value = lastViewUri != null
              ? lastViewUri.toString()
              : widget.initUrl;
          tabController.pageStorageKey.value = PageStorageKey<String>(
            Random().nextInt(1 << 32).toString(),
          );
          logger.i(
            'refreshBuildPage: ${tabController.url.value}',
          );
        }
      },
    );
  }

  void initPullToRefreshController() {
    pullToRefreshController =
        kIsWeb ||
            ![
              TargetPlatform.iOS,
              TargetPlatform.android,
            ].contains(defaultTargetPlatform)
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(color: KeychatGlobal.primaryColor),
            onRefresh: refreshPage,
          );
  }

  // Add new method to handle special URLs
  Future<bool> handleSpecialUrls(String urlString) async {
    try {
      if (urlString.startsWith('cashu')) {
        await ecashController.proccessCashuString(urlString);
        return true;
      }
      // lightning invoice
      if (urlString.startsWith('lightning:')) {
        final input = urlString.replaceFirst('lightning:', '');
        await ecashController.payToLightning(input, isPay: true);
        return true;
      }
      if (urlString.startsWith('lnbc')) {
        await ecashController.payToLightning(urlString, isPay: true);
        return true;
      }
      // Handle Bitcoin URIs
      if (urlString.startsWith('bitcoin:')) {
        await QrScanService.instance.handleBitcoinUri(
          urlString,
          ecashController,
        );
        return true;
      }
    } catch (e) {
      logger.i(e.toString(), error: e);
    }
    return false;
  }

  void _downloadBlob(String base64content, String ext) {
    logger.d('base64content: $base64content, ext $ext');
  }
}
