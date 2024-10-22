import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

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
            Icons.close,
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
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 50),
                  child: MarkdownBody(
                      data: text,
                      selectable: true,
                      softLineBreak: true,
                      styleSheet: MarkdownStyleSheet(
                          p: Theme.of(Get.context!)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontSize: 18)),
                      onTapLink: (url, url2, url3) {
                        if (!url.startsWith('http') && url2 != null) {
                          url = url2;
                        }
                        final Uri uri = Uri.parse(url);
                        Utils.hideKeyboard(Get.context!);
                        launchUrl(uri);
                      })))
        ]));
  }
}
