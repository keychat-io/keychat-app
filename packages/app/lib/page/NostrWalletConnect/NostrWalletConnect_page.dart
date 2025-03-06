import 'package:app/page/NostrWalletConnect/NostrWalletConnectLog.dart';
import 'package:app/page/components.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoDialogAction;
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
        leading: IconButton(
            onPressed: () {
              Get.dialog(CupertinoAlertDialog(
                  title: const Text('Disconnect and exit?'),
                  content: const Text(
                      'The next time will generate a new temporary wallet'),
                  actions: <Widget>[
                    CupertinoDialogAction(
                      child: const Text('Cancel'),
                      onPressed: () {
                        Get.back();
                      },
                    ),
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      child: const Text('Exit'),
                      onPressed: () {
                        Get.back();
                        Get.back();
                      },
                    ),
                  ]));
            },
            icon: const Icon(Icons.close)),
        title: const Text('NWC - NIP47'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () {
                  Get.to(() => NostrWalletConnectLog());
                },
                icon: Icon(Icons.access_time_outlined),
              ),
              Obx(() {
                final logsCount = controller.logs.length;
                return logsCount > 0
                    ? Positioned(
                        top: 3,
                        right: 3,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$logsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : const SizedBox.shrink();
              }),
            ],
          ),
        ],
      ),
      body: ListView(
        children: <Widget>[
          Obx(() => ListTile(
                leading: Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: controller.subscribeSuccessRelays.isNotEmpty
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                title: const Text('Connected Relay'),
                subtitle: controller.subscribeSuccessRelays.isNotEmpty
                    ? Wrap(
                        direction: Axis.vertical,
                        children: controller.subscribeSuccessRelays
                            .map((value) => textSmallGray(context, value))
                            .toList())
                    : const Text('None'),
                trailing: IconButton(
                    onPressed: () {
                      controller.startListening();
                      EasyLoading.showSuccess('Reconnecting');
                    },
                    icon: Icon(Icons.refresh)),
              )),
          SizedBox(height: 16),
          ListTile(
              title: const Text('Temporary Wallets'),
              subtitle: Obx(
                () => Column(children: [
                  textSmallGray(
                      context, 'Wallet: 0x${controller.service.value.pubkey}'),
                  textSmallGray(
                      context, 'Client: 0x${controller.client.value.pubkey}')
                ]),
              )),
          SizedBox(height: 16),
          Obx(() => controller.nwcUri.isNotEmpty &&
                  controller.subscribeSuccessRelays.isNotEmpty
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ListTile(
                    title: Text('WalletConnect URI'),
                    subtitle: textSmallGray(context, controller.nwcUri.value,
                        maxLines: 5),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          showModalBottomSheetWidget(
                              context,
                              'nostr+walletconnect://',
                              Center(
                                  child: Column(children: [
                                Utils.genQRImage(controller.nwcUri.value,
                                    size: 330),
                                const SizedBox(height: 64),
                                FilledButton(
                                  onPressed: () {
                                    Get.back();
                                  },
                                  child: const Text('Close'),
                                ),
                              ])));
                        },
                        child: const Text('QR Code'),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: () {
                          Clipboard.setData(
                                  ClipboardData(text: controller.nwcUri.value))
                              .then((_) {
                            EasyLoading.showSuccess('Copied');
                          });
                        },
                        child: const Text('Copy'),
                      ),
                    ],
                  )
                ])
              : Container()),
        ],
      ),
    );
  }
}
