import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'Browser_controller.dart';

class WebviewDetailPage extends StatefulWidget {
  final WebViewController webViewController;
  const WebviewDetailPage(this.webViewController, {super.key});

  @override
  _WebviewDetailPageState createState() => _WebviewDetailPageState();
}

class _WebviewDetailPageState extends State<WebviewDetailPage> {
  bool marked = false;
  late BrowserController controller;
  String? url;
  bool canGoBack = false;

  @override
  void initState() {
    super.initState();
    controller = Get.find<BrowserController>();
    controller.setUrlChangeCallBack((url) async {
      setState(() {
        canGoBack = true;
      });
    });
  }

  void initIsMarked() {
    widget.webViewController.currentUrl().then((value) async {
      if (value == null) return;
      BrowserBookmark? bb = await DBProvider.database.browserBookmarks
          .filter()
          .urlEqualTo(value)
          .findFirst();

      setState(() {
        url = value;
        marked = bb != null;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: GetPlatform.isAndroid ? false : true,
        onPopInvokedWithResult: (didPop, d) {
          if (didPop) {
            return;
          }
          goBackOrPop();
        },
        child: SafeArea(
            bottom: false,
            child: Scaffold(
              body: CustomScrollView(
                physics: const NeverScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    toolbarHeight: 40,
                    floating: true,
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
                    title: Obx(() => Text(controller.title.value)),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(0),
                      child: Obx(() => controller.progress.value > 0 &&
                              controller.progress.value < 1
                          ? LinearProgressIndicator(
                              value: controller.progress.value,
                              backgroundColor: Theme.of(context).indicatorColor,
                              minHeight: 2,
                            )
                          : Container()),
                    ),
                    actions: [
                      PopupMenuButton<String>(
                        onOpened: () {
                          initIsMarked();
                        },
                        onSelected: (value) async {
                          final url =
                              await widget.webViewController.currentUrl();
                          if (url == null) return;

                          switch (value) {
                            case 'share':
                              Share.share(url);
                              break;
                            case 'copy':
                              Clipboard.setData(ClipboardData(text: url));
                              EasyLoading.showToast('Copied');
                              break;
                            case 'openInBrowser':
                              await launchUrl(Uri.parse(url),
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
                                    style:
                                        Theme.of(context).textTheme.bodyLarge)
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'copy',
                              child: Row(spacing: 12, children: [
                                const Icon(CupertinoIcons.doc_on_clipboard),
                                Text('Copy',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge)
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'openInBrowser',
                              child: Row(spacing: 12, children: [
                                const Icon(CupertinoIcons.globe),
                                Text('Native Browser',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge)
                              ]),
                            ),
                          ];
                        },
                        icon: const Icon(Icons.more_vert),
                      ),
                    ],
                  ),
                  SliverFillRemaining(
                    child: WebViewWidget(controller: widget.webViewController),
                  ),
                ],
              ),
              floatingActionButton: kDebugMode
                  ? ElevatedButton(
                      onPressed: () async {
                        try {
                          var event = {
                            'created_at':
                                DateTime.now().millisecondsSinceEpoch ~/ 1000,
                            'kind': 1,
                            'tags': [
                              ['example', 'tag']
                            ],
                            'content': 'This is a demo event'
                          };
                          // await widget.webViewController
                          //     .runJavaScript('window.nostr.signEvent($event);');
                        } catch (e) {
                          logger.e(e, error: e);
                        }
                      },
                      child: const Text('Call'),
                    )
                  : null,
            )));
  }

  void goBackOrPop() {
    widget.webViewController.canGoBack().then((canGoBack) {
      if (canGoBack) {
        widget.webViewController.goBack();
      } else {
        Navigator.pop(Get.context!);
      }
    });
  }

  void troggleMarkUrl() async {
    final url = await widget.webViewController.currentUrl();
    if (url == null) return;
    BrowserBookmark? bb = await DBProvider.database.browserBookmarks
        .filter()
        .urlEqualTo(url)
        .findFirst();
    await DBProvider.database.writeTxn(() async {
      if (bb != null) {
        await DBProvider.database.browserBookmarks.delete(bb.id);
      } else {
        BrowserBookmark bookmark =
            BrowserBookmark(url: url, title: controller.title.value);
        await DBProvider.database.browserBookmarks.put(bookmark);
      }
    });
    setState(() {
      marked = !marked;
    });
    EasyLoading.showToast(marked ? 'Bookmarked' : 'Unbookmarked');
    controller.loadBookmarks();
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
            future: widget.webViewController.canGoBack(),
            builder: (context, snapshot) {
              bool canGoBack = snapshot.data ?? false;
              return IconButton(
                icon: const Icon(CupertinoIcons.arrow_left),
                onPressed: () async {
                  if (canGoBack) {
                    widget.webViewController.goBack();
                    Get.back();
                  }
                },
                color:
                    canGoBack ? Theme.of(context).iconTheme.color : Colors.grey,
              );
            },
          ),
          FutureBuilder<bool>(
              future: widget.webViewController.canGoForward(),
              builder: (context, snapshot) {
                bool can = snapshot.data ?? false;
                return IconButton(
                  icon: const Icon(CupertinoIcons.arrow_right),
                  onPressed: () async {
                    if (can) {
                      widget.webViewController.goForward();
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
                widget.webViewController.reload();
                Get.back();
              },
              icon: const Icon(CupertinoIcons.refresh)),
        ],
      ),
    );
  }
}
