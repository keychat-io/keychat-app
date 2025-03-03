import 'package:app/page/browser/Browser_page.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/page/login/me.dart';
import 'package:app/page/room_list.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CupertinoRootPage extends StatefulWidget {
  const CupertinoRootPage({super.key});

  @override
  State<CupertinoRootPage> createState() => _CupertinoRootPageState();
}

class _CupertinoRootPageState extends State<CupertinoRootPage> {
  late HomeController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<HomeController>();
    if (GetPlatform.isMobile) {
      initIntent();
    }
  }

  initIntent() {
    final sharedFiles = <SharedMediaFile>[];
    // Listen to media sharing coming from outside the app while the app is in the memory.

    ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      setState(() {
        sharedFiles.clear();
        sharedFiles.addAll(value);

        print(sharedFiles.map((f) => f.toMap()));
      });
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      setState(() {
        sharedFiles.clear();
        sharedFiles.addAll(value);
        print(sharedFiles.map((f) => f.toMap()));

        // Tell the library that we are done processing the intent.
        ReceiveSharingIntent.instance.reset();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    List configs = [
      {
        "page": const RoomList(),
        "barItem": BottomNavigationBarItem(
            label: 'Chats',
            icon: Obx(() => Badge(
                backgroundColor: Colors.red,
                textColor: Colors.white,
                label: Text('${controller.allUnReadCount.value}'),
                isLabelVisible: controller.allUnReadCount.value > 0,
                child: const Icon(CupertinoIcons.chat_bubble_fill, size: 22)))),
        "linux": true,
        "windows": true,
      },
      {
        "page": const BrowserPage(),
        "barItem": const BottomNavigationBarItem(
            label: 'Browser', icon: Icon(Icons.explore, size: 22)),
        "linux": false,
        "windows": false,
      },
      {
        "page": const MinePage(),
        "barItem": const BottomNavigationBarItem(
            label: 'Me', icon: Icon(CupertinoIcons.person_fill, size: 22)),
        "linux": true,
        "windows": true,
      }
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
          if (value == configs.length - 1) {
            EasyThrottle.throttle(
                'loadCashuABalance', const Duration(seconds: 3), () {
              getGetxController<EcashController>()?.getBalance();
            });
          }
        },
        items: configs
            .map((e) => e["barItem"] as BottomNavigationBarItem)
            .toList(),
      ),
      tabBuilder: (context, index) {
        return configs.elementAt(index)["page"] as Widget;
      },
    );
  }
}
