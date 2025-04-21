import 'package:app/controller/home.controller.dart';
import 'package:app/models/relay.dart';
import 'package:app/page/setting/RelaySetting.dart';
import 'package:app/service/websocket.service.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

import 'home_drop_menu.dart';

class RelayStatus extends GetView<HomeController> {
  const RelayStatus({super.key});

  @override
  Widget build(BuildContext context) {
    WebsocketService? ws;
    try {
      ws = Get.find<WebsocketService>();
    } catch (e) {
      return relayErrorIcon();
    }

    if (!controller.isConnectedNetwork.value) {
      return relayErrorIcon();
    }
    return Obx(() => ws!.relayStatusInt.value == RelayStatusEnum.connected.name
        ? GestureDetector(
            onLongPress: () {
              Get.to(() => const RelaySetting());
            },
            child: badges.Badge(
                showBadge: controller.addFriendTips.value,
                position: badges.BadgePosition.topEnd(top: 5, end: 5),
                child: HomeDropMenuWidget(controller.addFriendTips.value)))
        : (ws.relayStatusInt.value == RelayStatusEnum.connecting.name ||
                ws.relayStatusInt.value == RelayStatusEnum.init.name)
            ? SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  color: Colors.black,
                  icon: SpinKitDoubleBounce(
                    color: Colors.amber.shade200,
                    size: 22.0,
                    duration: const Duration(milliseconds: 4000),
                  ),
                  onPressed: () {
                    _showDialogForReconnect(false, "Relays connecting");
                  },
                ),
              )
            : relayErrorIcon());
  }

  Widget relayErrorIcon() {
    return SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          icon: Icon(Icons.error, color: Colors.red.shade400),
          onPressed: () {
            String message =
                'All relays connecting error, please check network';

            _showDialogForReconnect(false, message);
          },
        ));
  }

  _showDialogForReconnect(bool status, String message) {
    Get.dialog(CupertinoAlertDialog(
      title: status
          ? const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 34,
            )
          : const Icon(
              Icons.error,
              color: Colors.red,
              size: 34,
            ),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          child: const Text("Cancel"),
          onPressed: () async {
            Get.back();
          },
        ),
        CupertinoDialogAction(
          isDefaultAction: status,
          onPressed: () async {
            Get.find<WebsocketService>().init();
            EasyLoading.showToast('Relays connecting, please wait...');
            Get.back();
          },
          child: const Text("Reconnect"),
        ),
      ],
    ));
  }
}
