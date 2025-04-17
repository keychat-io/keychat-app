import 'package:app/global.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/utils.dart';
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
    controller.setCurrentTabIndex = (int index) {
      setState(() {
        currentTabIndex = index;
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    final stackKey = GlobalObjectKey('browser_stack');

    return Row(children: [
      Obx(() => Container(
          width: 260,
          padding: EdgeInsets.symmetric(vertical: 16),
          child: ListView.builder(
            itemCount: controller.tabs.length + 1,
            itemBuilder: (context, index) {
              if (index == controller.tabs.length) {
                return Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                        horizontal: 16, vertical: 8),
                    child: OutlinedButton.icon(
                        onPressed: () {
                          controller.addNewTab();
                        },
                        label: Icon(Icons.add)));
              }
              return HoverCloseListTile(
                leading: Utils.getNetworkImage(controller.tabs[index].favicon,
                    size: 24),
                title: controller.tabs[index].title == null ||
                        controller.tabs[index].title!.isEmpty
                    ? controller.tabs[index].url
                    : (controller.tabs[index].title ??
                        controller.tabs[index].url),
                selected: currentTabIndex == index,
                onTap: () {
                  controller.setCurrentTabIndex!(index);
                },
                onClose: () {
                  controller.removeByIndex(index);
                },
              );
            },
          ))),
      SizedBox(
        width: 1,
        height: double.infinity,
        child: VerticalDivider(
          thickness: 1,
          width: 1,
          color: Theme.of(context).dividerColor.withAlpha(50),
        ),
      ),
      Expanded(
          child: IndexedStack(
        key: stackKey,
        sizing: StackFit.expand,
        index: currentTabIndex,
        children: controller.tabs.map((e) => e.tab).toList(),
      ))
    ]);
  }
}

class HoverCloseListTile extends StatefulWidget {
  final Widget? leading;
  final String title;
  final bool selected;
  final VoidCallback onClose;
  final VoidCallback onTap;

  const HoverCloseListTile({
    super.key,
    required this.leading,
    required this.selected,
    required this.title,
    required this.onClose,
    required this.onTap,
  });

  @override
  _HoverCloseListTileState createState() => _HoverCloseListTileState();
}

class _HoverCloseListTileState extends State<HoverCloseListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ListTile(
        leading: widget.leading,
        selectedTileColor: KeychatGlobal.primaryColor.withValues(alpha: 200),
        contentPadding: EdgeInsets.only(left: 16, right: 4),
        title: Text(widget.title, maxLines: 1),
        selected: widget.selected,
        onTap: widget.onTap,
        trailing: AnimatedOpacity(
          opacity: _isHovered ? 1.0 : 0.0,
          duration: Duration(milliseconds: 200),
          child: _isHovered
              ? IconButton(
                  icon: Icon(Icons.close),
                  onPressed: widget.onClose,
                )
              : SizedBox(width: 48),
        ),
      ),
    );
  }
}
