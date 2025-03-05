import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import './NostrWalletConnect_controller.dart';

class NostrWalletConnectPage extends GetView<NostrWalletConnectController> {
  const NostrWalletConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Nostr Wallet Connect'),
        ),
        body: Container(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Obx(() => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  controller.socketStatus.value == 'connected'
                                      ? Colors.green
                                      : controller.socketStatus.value ==
                                              'connecting'
                                          ? Colors.orange
                                          : Colors.red,
                            ),
                          ),
                          Text('Status: ${controller.socketStatus.value}'),
                        ],
                      ),
                    )),
                ElevatedButton(
                  onPressed: controller.reconnect,
                  child: const Text('Reconnect'),
                ),
                const SizedBox(height: 24),
                Obx(() => Text(controller.nwcUri.value)),
                const SizedBox(height: 8),
                Obx(() => controller.nwcUri.isNotEmpty
                    ? OutlinedButton(
                        onPressed: () {
                          Clipboard.setData(
                                  ClipboardData(text: controller.nwcUri.value))
                              .then((_) {
                            EasyLoading.showSuccess('Copied');
                          });
                        },
                        child: const Text('Copy'),
                      )
                    : Container()),
                FilledButton(
                    onPressed: () {
                      controller.test();
                    },
                    child: const Text('Test')),
              ],
            ),
          ),
        ));
  }
}
