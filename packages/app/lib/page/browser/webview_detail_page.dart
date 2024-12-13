import 'package:app/utils.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'Browser_controller.dart';

class WebviewDetailPage extends GetView<BrowserController> {
  final WebViewController webViewController;
  const WebviewDetailPage(this.webViewController, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.title.value)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Obx(() =>
              controller.progress.value > 0 && controller.progress.value < 1
                  ? LinearProgressIndicator(
                      value: controller.progress.value,
                      backgroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    )
                  : Container()),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              final url = await webViewController.currentUrl();
              if (value == 'share') {
                Share.share('$url');
              } else if (value == 'copy') {
                Clipboard.setData(ClipboardData(text: url ?? ''));
                Get.snackbar('Copied', 'URL has been copied to clipboard');
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'share',
                  child: Text('Share'),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: Text('Copy'),
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
                  // await webViewController.runJavaScript(
                  //     'window.nc.sendMessage({action: "getPublicKey"})');
// async window.nostr.signEvent(event: { created_at: number, kind: number, tags: string[][], content: string }): Event // takes an event object, adds `id`, `pubkey` and `sig` and returns it
                  var event = {
                    'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                    'kind': 1,
                    'tags': [
                      ['example', 'tag']
                    ],
                    'content': 'This is a demo event'
                  };
                  await webViewController
                      .runJavaScript('window.nostr.signEvent($event);');
                } catch (e) {
                  logger.e(e, error: e);
                }
              },
              child: const Text('Call'),
            )
          : null,
      body: SafeArea(child: WebViewWidget(controller: webViewController)),
    );
  }
}
