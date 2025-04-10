import 'package:app/controller/home.controller.dart';
import 'package:app/desktop/DesktopController.dart';
import 'package:app/page/browser/Browser_page.dart';
import 'package:app/page/chat/chat_page.dart';
import 'package:app/page/login/me.dart';
import 'package:app/page/room_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/cashu_page.dart';
import 'package:sidebarx/sidebarx.dart';

class DesktopMain extends GetView<DesktopController> {
  const DesktopMain({super.key});

  @override
  Widget build(BuildContext context) {
    DesktopController dc = Get.find<DesktopController>();
    return Scaffold(
      key: controller.globalKey,
      body: Row(
        children: [
          HomeSidebarX(controller: controller.sidebarXController),
          Expanded(
              child: AnimatedBuilder(
            animation: controller.sidebarXController,
            builder: (context, child) {
              switch (controller.sidebarXController.selectedIndex) {
                case 0:
                  return Row(
                    children: [
                      SizedBox(
                        width: 280,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              right: BorderSide(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withAlpha(40),
                                width: 1,
                              ),
                            ),
                          ),
                          child: RoomList(),
                        ),
                      ),
                      Expanded(
                          child: Obx(() =>
                              dc.selectedRoom.value.identityId == -1
                                  ? const Center(child: Text('Keychat.io'))
                                  : ChatPage(
                                      key: ValueKey(dc.selectedRoom.value.id),
                                      room: dc.selectedRoom.value))),
                    ],
                  );
                case 1:
                  return const BrowserPage();
                case 2:
                  return const CashuPage();
                case 3:
                  return const MinePage();
                default:
                  return Text(
                    controller.sidebarXController.selectedIndex.toString(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  );
              }
            },
          )),
        ],
      ),
    );
  }
}

final double iconSize = 24;

class HomeSidebarX extends GetView<HomeController> {
  const HomeSidebarX({
    super.key,
    required SidebarXController controller,
  }) : _controller = controller;

  final SidebarXController _controller;

  @override
  Widget build(BuildContext context) {
    return SidebarX(
      controller: _controller,
      theme: SidebarXTheme(
        decoration: BoxDecoration(
          color: Color(0xFFE8E8E8),
        ),
        margin: const EdgeInsets.all(0),
        hoverColor: scaffoldBackgroundColor,
        hoverTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        itemTextPadding: const EdgeInsets.only(left: 30),
        selectedItemTextPadding: const EdgeInsets.only(left: 30),
        itemDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          // border: Border.all(color: canvasColor),
        ),
        selectedItemDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [accentCanvasColor, canvasColor],
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              blurRadius: 30,
            )
          ],
        ),
        iconTheme: IconThemeData(
          size: iconSize,
        ),
        selectedIconTheme: IconThemeData(
          color: Colors.white,
          size: iconSize,
        ),
      ),
      showToggleButton: false, // footerDivider: divider,
      headerBuilder: (context, extended) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Image.asset('assets/images/logo.png'),
        );
      },
      items: [
        SidebarXItem(
          iconBuilder: (selected, hovered) {
            return Obx(() => Badge(
                backgroundColor: Colors.red,
                label: Text('${controller.allUnReadCount.value}'),
                isLabelVisible: controller.allUnReadCount.value > 0,
                child: selected
                    ? Icon(CupertinoIcons.chat_bubble_fill,
                        color: Colors.white, size: iconSize)
                    : Icon(CupertinoIcons.chat_bubble,
                        color: Colors.black, size: iconSize)));
          },
          onTap: () {
            debugPrint('Chats');
          },
        ),
        const SidebarXItem(icon: CupertinoIcons.compass),
        SidebarXItem(iconBuilder: (selected, hovered) {
          return Icon(
            CupertinoIcons.bitcoin,
            color: Color(0xfff2a900),
            size: iconSize,
          );
        }),
        const SidebarXItem(icon: CupertinoIcons.settings),
      ],
    );
  }
}

const primaryColor = Color(0xFF685BFF);
const canvasColor = Color(0xFF2E2E48);
const scaffoldBackgroundColor = Color(0xFF464667);
const accentCanvasColor = Color(0xFF3E3E61);
const white = Colors.white;
final actionColor = const Color(0xFF5F5FA7).withOpacity(0.6);
final divider = Divider(color: white.withOpacity(0.3), height: 1);
