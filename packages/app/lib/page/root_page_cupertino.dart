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

class CupertinoRootPage extends StatefulWidget {
  const CupertinoRootPage({super.key});

  @override
  State<CupertinoRootPage> createState() => _CupertinoRootPageState();
}

class _CupertinoRootPageState extends State<CupertinoRootPage> {
  int _selectedIndex = 0;
  List configs = [];

  @override
  void initState() {
    configs = [const RoomList(), const BrowserPage(), const MinePage()];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      restorationId: 'cupertino_tab_scaffold',
      resizeToAvoidBottomInset: true,
      tabBar: CupertinoTabBar(
        currentIndex: _selectedIndex,
        onTap: (value) async {
          if (EasyLoading.isShow) {
            EasyLoading.dismiss();
          }
          if (GetPlatform.isMobile) {
            HapticFeedback.lightImpact();
          }
          if (value == configs.length - 1) {
            EasyThrottle.throttle(
                'loadCashuABalance', const Duration(seconds: 3), () {
              Utils.getGetxController<EcashController>()?.getBalance();
            });
          }
          setState(() {
            _selectedIndex = value;
          });
        },
        iconSize: 24,
        items: [
          BottomNavigationBarItem(
              label: 'Chats',
              icon: Obx(() => Badge(
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  label: Text(
                      '${Get.find<HomeController>().allUnReadCount.value}'),
                  isLabelVisible:
                      Get.find<HomeController>().allUnReadCount.value > 0,
                  child: const Icon(CupertinoIcons.chat_bubble_fill)))),
          const BottomNavigationBarItem(
              label: 'Browser', icon: Icon(Icons.explore)),
          const BottomNavigationBarItem(
              label: 'Me', icon: Icon(CupertinoIcons.person_fill))
        ],
      ),
      tabBuilder: (context, index) {
        return configs[index];
      },
    );
  }
}
