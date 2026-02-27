import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:markdown_widget/markdown_widget.dart';

class LongTextPreviewPage extends StatelessWidget {
  const LongTextPreviewPage(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: IconButton(
        onPressed: () {
          Get.back<void>();
        },
        icon: const Icon(
          CupertinoIcons.clear_circled,
          color: Colors.purple,
        ),
      ),
      body: Stack(
        children: <Widget>[
          GestureDetector(
            onDoubleTap: () {
              Navigator.pop(context);
            },
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
              child: MarkdownBlock(data: text, config: RoomUtil.markdownConfig),
            ),
          ),
        ],
      ),
    );
  }
}
