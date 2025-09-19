import 'package:app/desktop/DesktopController.dart';
import 'package:app/global.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const GlobalObjectKey<State<StatefulWidget>> stackKey =
      GlobalObjectKey('browser_stack_desktop');
  final FocusNode _focusNode = FocusNode();

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
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // ignore: unused_element
  KeyEventResult _handleKeyEvent(KeyEvent event) {
    logger.d(
        'KeyEvent detected: ${event.logicalKey.keyLabel}, type: ${event.runtimeType}');

    if (event is KeyDownEvent) {
      // Check for Cmd+W (Mac) or Ctrl+W (other platforms)
      if (event.logicalKey == LogicalKeyboardKey.keyW) {
        final isModifierPressed = GetPlatform.isMacOS
            ? HardwareKeyboard.instance.isMetaPressed
            : HardwareKeyboard.instance.isControlPressed;

        if (isModifierPressed) {
          logger.d('Detected Cmd/Ctrl+W combination');
          if (controller.tabs.isNotEmpty &&
              currentTabIndex < controller.tabs.length) {
            controller.removeByIndex(currentTabIndex);
          }
          return KeyEventResult.handled;
        }
      }

      // Check for Cmd+N (Mac) or Ctrl+N (other platforms)
      if (event.logicalKey == LogicalKeyboardKey.keyN) {
        final isModifierPressed = GetPlatform.isMacOS
            ? HardwareKeyboard.instance.isMetaPressed
            : HardwareKeyboard.instance.isControlPressed;

        if (isModifierPressed) {
          logger.d('Detected Cmd/Ctrl+N combination');
          controller.addNewTab();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Obx(() => Container(
          width: desktopController.browserSidebarWidth.value,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ListView.builder(
            itemCount: controller.tabs.length + 1,
            itemBuilder: (context, index) {
              if (index == controller.tabs.length) {
                return Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16, vertical: 8),
                    child: OutlinedButton.icon(
                        onPressed: () {
                          controller.addNewTab();
                        },
                        label: const Icon(Icons.add)));
              }
              final tab = controller.tabs[index];
              return HoverCloseListTile(
                leading: Utils.getNetworkImage(controller.tabs[index].favicon,
                    size: 20),
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
                  desktopController.browserSidebarWidth.value +
                      details.delta.dx,
                );
              },
              child: Container(
                  width: 1,
                  decoration: BoxDecoration(
                      border: Border(
                    right: BorderSide(
                        color: Theme.of(context).dividerColor.withAlpha(30)),
                  ))))),
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
  const HoverCloseListTile({
    required this.leading,
    required this.selected,
    required this.title,
    required this.onClose,
    required this.onTap,
    super.key,
  });
  final Widget? leading;
  final String title;
  final bool selected;
  final VoidCallback onClose;
  final VoidCallback onTap;

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
        child: Stack(
          children: [
            ListTile(
              leading: widget.leading,
              horizontalTitleGap: 6,
              selectedTileColor:
                  KeychatGlobal.primaryColor.withValues(alpha: 200),
              contentPadding: const EdgeInsets.only(left: 12, right: 4),
              title: Text(widget.title,
                  style: Theme.of(context).textTheme.bodyMedium, maxLines: 1),
              selected: widget.selected,
              onTap: widget.onTap,
            ),
            Positioned(
                right: 0,
                top: 4,
                child: AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: _isHovered
                      ? IconButton(
                          iconSize: 20,
                          icon: const Icon(Icons.close),
                          hoverColor:
                              KeychatGlobal.primaryColor.withValues(alpha: 100),
                          onPressed: widget.onClose,
                        )
                      : const SizedBox(width: 48),
                ))
          ],
        ));
  }
}
