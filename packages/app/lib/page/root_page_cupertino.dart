import 'package:app/page/browser/Browser_page.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/page/login/me.dart';
import 'package:app/page/room_list.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CupertinoRootPage extends GetView<HomeController> {
  const CupertinoRootPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [
      const RoomList(),
      // const BrowserPage(),
      const MinePage(),
    ];
    return CupertinoTabScaffold(
      restorationId: 'cupertino_tab_scaffold',
      resizeToAvoidBottomInset: true,
      tabBar: CupertinoTabBar(
        onTap: (value) async {
          if (EasyLoading.isShow) {
            EasyLoading.dismiss();
          }
          if (GetPlatform.isMobile) {
            HapticFeedback.lightImpact();
          }
          if (value == pages.length - 1) {
            EasyThrottle.throttle(
                'loadCashuABalance', const Duration(seconds: 3), () {
              getGetxController<EcashController>()?.getBalance();
            });
          }
        },
        items: [
          BottomNavigationBarItem(
              label: 'Chats',
              icon: Obx(() => Badge(
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  label: Text('${controller.allUnReadCount.value}'),
                  isLabelVisible: controller.allUnReadCount.value > 0,
                  child:
                      const Icon(CupertinoIcons.chat_bubble_fill, size: 22)))),
          // const BottomNavigationBarItem(
          //     label: 'Browser', icon: Icon(Icons.explore, size: 22)),
          const BottomNavigationBarItem(
              label: 'Me', icon: Icon(CupertinoIcons.person_fill, size: 22))
        ],
      ),
      tabBuilder: (context, index) {
        return pages[index];
      },
    );
  }
}
