import 'package:app/desktop/DesktopController.dart';
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
  late DesktopController desktopController;
  int currentTabIndex = 0;
  final stackKey = GlobalObjectKey('browser_stack_desktop');

  @override
  void initState() {
    super.initState();
    controller = Get.find<MultiWebviewController>();
    desktopController = Get.find<DesktopController>();
    controller.updatePageTabIndex = (int index) {
      setState(() {
        currentTabIndex = index;
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Obx(() => Container(
          width: desktopController.browserSidebarWidth.value,
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
              var tab = controller.tabs[index];
              return HoverCloseListTile(
                leading: Utils.getNetworkImage(controller.tabs[index].favicon,
                    size: 24),
                title: controller.removeHttpPrefix(
                    tab.title == null || tab.title!.isEmpty
                        ? tab.url
                        : (tab.title ?? tab.url)),
                selected: currentTabIndex == index,
                onTap: () {
                  controller.setCurrentTabIndex(index);
                },
                onClose: () {
                  controller.removeByIndex(index);
                },
              );
            },
          ))),
      MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            desktopController.setBrowserSidebarWidth(
              desktopController.browserSidebarWidth.value + details.delta.dx,
            );
          },
          child: Container(
            width: 1,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor.withAlpha(30),
                  width: 1,
                ),
              ),
            ),
          ),
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
        horizontalTitleGap: 8,
        selectedTileColor: KeychatGlobal.primaryColor.withValues(alpha: 200),
        contentPadding: EdgeInsets.only(left: 16, right: 4),
        title: Text(widget.title,
            style: Theme.of(context).textTheme.bodyMedium, maxLines: 1),
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
