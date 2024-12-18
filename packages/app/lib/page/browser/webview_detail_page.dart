import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  @override
  void initState() {
    super.initState();
    controller = Get.find<BrowserController>();
    controller.setUrlChanged(init);
    init();

    // widget.webViewController.setOnScrollPositionChange((scrollPositionChange) {
    //   print('scrollPositionChange: ${scrollPositionChange.y}');
    // });
  }

  void init() {
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close)),
        centerTitle: true,
        title: Obx(() => Text(controller.title.value)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Obx(() =>
              controller.progress.value > 0 && controller.progress.value < 1
                  ? LinearProgressIndicator(
                      value: controller.progress.value,
                      backgroundColor: Theme.of(context).indicatorColor,
                      minHeight: 1,
                    )
                  : Container()),
        ),
        actions: [
          IconButton(
            icon: marked
                ? const Icon(CupertinoIcons.heart_fill)
                : const Icon(CupertinoIcons.heart),
            onPressed: () async {
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
              controller.loadBookmarks();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final url = await widget.webViewController.currentUrl();
              if (url == null) return;

              switch (value) {
                case 'back':
                  widget.webViewController.goBack();
                  break;
                case 'refresh':
                  widget.webViewController.reload();
                  break;
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
                const PopupMenuItem(
                  value: 'back',
                  child: Text('Back'),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Text('Refresh'),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Text('Share'),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: Text('Copy'),
                ),
                const PopupMenuItem(
                  value: 'openInBrowser',
                  child: Text('Open in Browser'),
                ),
              ];
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      floatingActionButton: kDebugMode
          ? ElevatedButton(
              onPressed: () async {
                try {
                  var event = {
                    'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
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
      body:
          SafeArea(child: WebViewWidget(controller: widget.webViewController)),
    );
  }
}
