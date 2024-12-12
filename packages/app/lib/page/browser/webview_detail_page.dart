import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
      ),
      body: WebViewWidget(controller: webViewController),
    );
  }
}
