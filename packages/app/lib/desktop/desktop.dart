import 'package:app/app.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/desktop/DeskBrowser.dart';
import 'package:app/desktop/DeskEcash.dart';
import 'package:app/desktop/DeskRoomList.dart';
import 'package:app/desktop/DeskSetting.dart';
import 'package:app/desktop/DesktopController.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:sidebarx/sidebarx.dart';

class DesktopMain extends GetView<DesktopController> {
  const DesktopMain({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: controller.globalKey,
      body: Row(
        children: [
          const HomeSidebarX(),
          Expanded(
            child: AnimatedBuilder(
              animation: controller.sidebarXController,
              builder: (context, child) {
                return IndexedStack(
                  index: controller.sidebarXController.selectedIndex,
                  sizing: StackFit.expand,
                  children: const [
                    DeskRoomList(key: GlobalObjectKey('desk_tab0')),
                    DeskBrowser(key: GlobalObjectKey('desk_tab1')),
                    DeskEcash(key: GlobalObjectKey('desk_tab2')),
                    DeskSetting(key: GlobalObjectKey('desk_tab3')),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

const double iconSize = 24;

class HomeSidebarX extends GetView<DesktopController> {
  const HomeSidebarX({super.key});
  @override
  Widget build(BuildContext context) {
    final hc = Get.find<HomeController>();

    return SidebarX(
      controller: controller.sidebarXController,
      theme: SidebarXTheme(
        width: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2E243F)
              : const Color(0xFFE8E8E8),
        ),
        hoverColor: KeychatGlobal.primaryColor.withAlpha(200),
        hoverIconTheme: const IconThemeData(
          color: Colors.white,
          size: iconSize,
        ),
        itemTextPadding: const EdgeInsets.only(left: 30),
        selectedItemTextPadding: const EdgeInsets.only(left: 30),
        itemDecoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
        selectedItemDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [
              KeychatGlobal.primaryColor,
              KeychatGlobal.primaryColor,
            ],
          ),
        ),
        iconTheme: const IconThemeData(size: iconSize),
        selectedIconTheme:
            const IconThemeData(color: Colors.white, size: iconSize),
      ),
      showToggleButton: false, // footerDivider: divider,
      headerBuilder: (context, extended) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Image.asset('assets/images/logo.png'),
        );
      },
      items: [
        SidebarXItem(
          iconBuilder: (selected, hovered) {
            return Obx(
              () => Badge(
                backgroundColor: Colors.red,
                label: Text(
                  '${hc.allUnReadCount.value}',
                  style: const TextStyle(color: Colors.white),
                ),
                isLabelVisible: hc.allUnReadCount.value > 0,
                child: selected || hovered
                    ? const Icon(
                        CupertinoIcons.chat_bubble_fill,
                        color: Colors.white,
                        size: iconSize,
                      )
                    : Icon(
                        CupertinoIcons.chat_bubble,
                        color: Get.isDarkMode ? Colors.white : Colors.black,
                        size: iconSize,
                      ),
              ),
            );
          },
        ),
        SidebarXItem(
          icon: CupertinoIcons.compass,
          onTap: () {
            Get.find<MultiWebviewController>().checkCurrentControllerAlive();
          },
        ),
        SidebarXItem(
          iconBuilder: (selected, hovered) {
            return const Icon(
              CupertinoIcons.bitcoin,
              color: Color(0xfff2a900),
              size: iconSize,
            );
          },
          onTap: () {
            EasyThrottle.throttle(
                'loadCashuABalance', const Duration(seconds: 1), () {
              Utils.getGetxController<EcashController>()?.requestPageRefresh();
            });
          },
        ),
        const SidebarXItem(icon: CupertinoIcons.person),
      ],
    );
  }
}
