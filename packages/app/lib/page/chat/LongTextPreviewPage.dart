import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:markdown_widget/markdown_widget.dart';

class LongTextPreviewPage extends StatelessWidget {
  final String text;
  const LongTextPreviewPage(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: const Icon(
            CupertinoIcons.clear_circled,
            color: Colors.purple,
          ),
        ),
        body: Stack(children: <Widget>[
          GestureDetector(
            onDoubleTap: () {
              Navigator.pop(context);
            },
          ),
          Center(
              child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
                  child: MarkdownBlock(
                      data: text,
                      selectable: true,
                      config: (Get.isDarkMode
                              ? MarkdownConfig.darkConfig
                              : MarkdownConfig.defaultConfig)
                          .copy(configs: [
                        const PConfig(textStyle: TextStyle(fontSize: 20)),
                        LinkConfig(onTap: (url) {
                          Utils.hideKeyboard(Get.context!);
                          Get.find<MultiWebviewController>()
                              .launchWebview(initUrl: url);
                        })
                      ]))))
        ]));
  }
}
