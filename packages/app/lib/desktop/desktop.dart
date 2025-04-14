import 'package:app/controller/home.controller.dart';
import 'package:app/desktop/DeskRoomList.dart';
import 'package:app/desktop/DesktopController.dart';
import 'package:app/page/browser/Browser_page.dart';
import 'package:app/page/login/me.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/cashu_page.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:sidebarx/sidebarx.dart';

class DesktopMain extends GetView<DesktopController> {
  const DesktopMain({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DeskRoomList(key: GlobalObjectKey('tab0')),
      const BrowserPage(key: GlobalObjectKey('tab1')),
      const CashuPage(key: GlobalObjectKey('tab2')),
      const MinePage(key: GlobalObjectKey('tab3')),
    ];

    return Scaffold(
      key: controller.globalKey,
      body: Row(
        children: [
          HomeSidebarX(),
          Expanded(
            child: AnimatedBuilder(
              animation: controller.sidebarXController,
              builder: (context, child) {
                return IndexedStack(
                  index: controller.sidebarXController.selectedIndex,
                  sizing: StackFit.expand,
                  children: pages,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final double iconSize = 24;

class HomeSidebarX extends GetView<DesktopController> {
  const HomeSidebarX({super.key});
  @override
  Widget build(BuildContext context) {
    HomeController hc = Get.find<HomeController>();

    const canvasColor = Color(0xFF2E2E48);
    const scaffoldBackgroundColor = Color(0xFF464667);
    const accentCanvasColor = Color(0xFF3E3E61);

    return SidebarX(
      controller: controller.sidebarXController,
      theme: SidebarXTheme(
        width: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF2E243F)
              : Color(0xFFE8E8E8),
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
        ),
        selectedItemDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient:
                const LinearGradient(colors: [accentCanvasColor, canvasColor])),
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
                label: Text('${hc.allUnReadCount.value}',
                    style: const TextStyle(color: Colors.white)),
                isLabelVisible: hc.allUnReadCount.value > 0,
                child: selected
                    ? Icon(CupertinoIcons.chat_bubble_fill,
                        color: Colors.white, size: iconSize)
                    : Icon(CupertinoIcons.chat_bubble,
                        color: Get.isDarkMode ? Colors.white : Colors.black,
                        size: iconSize)));
          },
        ),
        const SidebarXItem(icon: CupertinoIcons.compass),
        SidebarXItem(
          iconBuilder: (selected, hovered) {
            return Icon(
              CupertinoIcons.bitcoin,
              color: Color(0xfff2a900),
              size: iconSize,
            );
          },
          onTap: () {
            EasyThrottle.throttle(
                'loadCashuABalance', const Duration(seconds: 3), () {
              Utils.getGetxController<EcashController>()?.getBalance();
            });
          },
        ),
        const SidebarXItem(icon: CupertinoIcons.settings),
      ],
    );
  }
}
