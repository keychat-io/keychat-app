import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MobileBrowser extends StatefulWidget {
  const MobileBrowser({super.key});

  @override
  State<MobileBrowser> createState() => _MobileBrowserState();
}

class _MobileBrowserState extends State<MobileBrowser> {
  late MultiWebviewController controller;
  int currentTabIndex = 0;
  final stackKey = GlobalObjectKey('browser_stack_mobile');
  @override
  void initState() {
    controller = Get.find<MultiWebviewController>();
    // controller.updateIndexedStackIndex = (int index) {
    //   setState(() {
    //     currentTabIndex = index;
    //   });
    // };
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      key: stackKey,
      sizing: StackFit.expand,
      index: currentTabIndex,
      children: controller.tabs.map((e) => e.tab).toList(),
    );
  }
}
