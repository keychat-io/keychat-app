import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/page/browser/BrowserNewTab.dart';
import 'package:keychat/page/login/me.dart';
import 'package:keychat/page/room_list.dart';
import 'package:keychat/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/keychat_ecash.dart';

class CupertinoRootPage extends StatefulWidget {
  const CupertinoRootPage({super.key});

  @override
  State<CupertinoRootPage> createState() => _CupertinoRootPageState();
}

class _CupertinoRootPageState extends State<CupertinoRootPage> {
  int _selectedIndex = KeychatGlobal.defaultOpenTabIndex;
  List<Widget> pages = [];
  late HomeController homeController;

  @override
  void initState() {
    pages = [const RoomList(), const BrowserNewTab(), const MinePage()];
    homeController = Get.find<HomeController>();
    super.initState();
    unawaited(homeController.biometricsAuth(auth: true));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CupertinoTabScaffold(
          controller: homeController.cupertinoTabController,
          tabBar: CupertinoTabBar(
            onTap: (int index) {
              setState(() {
                _selectedIndex = index;
              });
              if (EasyLoading.isShow) {
                EasyLoading.dismiss();
              }
              if (GetPlatform.isMobile) {
                HapticFeedback.lightImpact();
              }
              if (index == pages.length - 1) {
                EasyThrottle.throttle(
                  'loadCashuABalance',
                  const Duration(seconds: 1),
                  () {
                    Utils.getGetxController<EcashController>()
                        ?.requestPageRefresh();
                  },
                );
              }
            },
            iconSize: 26,
            currentIndex: _selectedIndex,
            items: [
              BottomNavigationBarItem(
                label: 'Chats',
                activeIcon: Obx(
                  () => Badge(
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    label: Text('${homeController.allUnReadCount.value}'),
                    isLabelVisible: homeController.allUnReadCount.value > 0,
                    child: const Icon(
                      CupertinoIcons.chat_bubble_fill,
                      color: KeychatGlobal.primaryColor,
                      size: 26,
                    ),
                  ),
                ),
                icon: Obx(
                  () => Badge(
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    label: Text('${homeController.allUnReadCount.value}'),
                    isLabelVisible: homeController.allUnReadCount.value > 0,
                    child: const Icon(CupertinoIcons.chat_bubble, size: 26),
                  ),
                ),
              ),
              const BottomNavigationBarItem(
                label: 'Browser',
                icon: Icon(CupertinoIcons.compass),
                activeIcon: Icon(
                  CupertinoIcons.compass_fill,
                  color: KeychatGlobal.primaryColor,
                ),
              ),
              const BottomNavigationBarItem(
                label: 'Me',
                activeIcon: Icon(
                  CupertinoIcons.person_fill,
                  color: KeychatGlobal.primaryColor,
                ),
                icon: Icon(CupertinoIcons.person),
              ),
            ],
          ),
          tabBuilder: (BuildContext context, int index) {
            return CupertinoTabView(
              builder: (BuildContext context) {
                return pages[index];
              },
            );
          },
        ),
        // Privacy protection blur layer
        if (GetPlatform.isMobile)
          Obx(
            () => homeController.isBlurred.value
                ? Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: ColoredBox(
                        color: Colors.black.withAlpha(30),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.lock_shield_fill,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
