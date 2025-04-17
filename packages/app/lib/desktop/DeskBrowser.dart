import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeskBrowser extends StatefulWidget {
  const DeskBrowser({super.key});

  @override
  State<DeskBrowser> createState() => _DeskBrowserState();
}

class _DeskBrowserState extends State<DeskBrowser> {
  late MultiWebviewController controller;
  int currentTabIndex = 0;
  @override
  void initState() {
    super.initState();
    controller = Get.find<MultiWebviewController>();
  }

  @override
  Widget build(BuildContext context) {
    final stackKey = ValueKey('browser_stack');

    return Row(children: [
      Obx(() => SizedBox(
          width: 260,
          child: ListView.builder(
            itemCount: controller.webViewTabs.length + 1,
            itemBuilder: (context, index) {
              if (index == controller.webViewTabs.length) {
                return ListTile(
                  title: const Text('Add Tab'),
                  onTap: () {
                    controller.addNewTab();
                  },
                );
              }
              return ListTile(
                title: Text(controller.webViewTabs[index].initUrl),
                selected: controller.currentTabIndex.value == index,
                onTap: () {
                  setState(() {
                    currentTabIndex = index;
                  });
                },
              );
            },
          ))),
      Expanded(
          child: IndexedStack(
        key: stackKey,
        sizing: StackFit.expand,
        index: currentTabIndex,
        children: controller.webViewTabs,
      ))
    ]);
  }
}
