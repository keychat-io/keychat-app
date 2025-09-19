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

import 'package:app/page/widgets/home_drop_menu.dart';

class RelayStatus extends GetView<HomeController> {
  const RelayStatus({super.key});

  @override
  Widget build(BuildContext context) {
    // Add a reactive variable to track WebsocketService availability
    final wsService = Rx<WebsocketService?>(null);

    // Try to find the service with retries
    _findWebsocketService(wsService);

    // Wrap the entire widget with Obx to make it reactive to both network status and service availability
    return Obx(() {
      // Check network connection first
      if (!controller.isConnectedNetwork.value) {
        return relayErrorIcon();
      }

      // Check if WebsocketService is available
      final ws = wsService.value;
      if (ws == null) {
        return relayErrorIcon();
      }

      // Now handle relay status based on the available service
      return Obx(() => ws.mainRelayStatus.value ==
              RelayStatusEnum.connected.name
          ? GestureDetector(
              onLongPress: () {
                Get.to(() => const RelaySetting());
              },
              child: badges.Badge(
                  showBadge: controller.addFriendTips.value,
                  position: badges.BadgePosition.topEnd(top: 5, end: 5),
                  child: HomeDropMenuWidget(controller.addFriendTips.value)))
          : (ws.mainRelayStatus.value == RelayStatusEnum.connecting.name ||
                  ws.mainRelayStatus.value == RelayStatusEnum.init.name)
              ? SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    color: Colors.black,
                    icon: SpinKitDoubleBounce(
                      color: Colors.amber.shade200,
                      size: 22,
                      duration: const Duration(milliseconds: 4000),
                    ),
                    onPressed: () {
                      _showDialogForReconnect(false, 'Relays connecting');
                    },
                  ),
                )
              : relayErrorIcon());
    });
  }

  void _findWebsocketService(Rx<WebsocketService?> wsService) {
    // First immediate attempt
    try {
      wsService.value = Get.find<WebsocketService>();
      if (wsService.value != null) return; // Successfully found the service
    } catch (e) {
      // Service not available yet
    }

    // If not found, start retry logic
    var attempts = 1; // Already made 1 attempt
    const maxAttempts = 10;
    const delay = Duration(milliseconds: 200);

    void tryFindService() {
      Future.delayed(delay, () {
        try {
          wsService.value = Get.find<WebsocketService>();
          if (wsService.value != null) return; // Successfully found the service
        } catch (e) {
          // Failed to find the service
        }

        attempts++;
        if (attempts < maxAttempts) {
          tryFindService(); // Recursive call for next attempt
        }
      });
    }

    // Start the retry process
    tryFindService();
  }

  Widget relayErrorIcon() {
    return SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          icon: Icon(Icons.error, color: Colors.red.shade400),
          onPressed: () {
            const message = 'All relays connecting error, please check network';

            _showDialogForReconnect(false, message);
          },
        ));
  }

  void _showDialogForReconnect(bool status, String message) {
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
          child: const Text('Cancel'),
          onPressed: () async {
            Get.back<void>();
          },
        ),
        CupertinoDialogAction(
          isDefaultAction: status,
          onPressed: () async {
            Get.find<WebsocketService>().init();
            EasyLoading.showToast('Relays connecting, please wait...');
            Get.back<void>();
          },
          child: const Text('Reconnect'),
        ),
      ],
    ));
  }
}
