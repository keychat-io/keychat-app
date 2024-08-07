import 'package:app/models/relay.dart';
import 'package:app/nostr-core/relay_websocket.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import './relay_info_controller.dart';

class RelayInfoPage extends GetView<RelayInfoController> {
  const RelayInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    WebsocketService ws = Get.find<WebsocketService>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Obx(() => Text(controller.relay.value.url)),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.of(context).restorablePush(_modalBuilder);
              },
              icon: const Icon(Icons.more_horiz))
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Obx(() => Visibility(
              visible:
                  ws.channels[controller.relay.value.url]?.relay.errorMessage !=
                      null,
              child: ListTile(
                  leading: const Icon(
                    Icons.warning_amber,
                    color: Colors.red,
                  ),
                  title: const Text('Error'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      RelayWebsocket? rw =
                          ws.channels[controller.relay.value.url];
                      if (rw != null) {
                        if (ws.channels[controller.relay.value.url]
                                ?.channelStatus ==
                            RelayStatusEnum.failed) {
                          rw.failedTimes = 1;
                          EasyLoading.showToast('Reconnecting');
                          ws.onErrorProcess(rw);
                        }
                      }
                    },
                  ),
                  subtitle: Text(ws.channels[controller.relay.value.url]?.relay
                          .errorMessage ??
                      '')))),
          Obx(() => Expanded(
                  child: SettingsList(platform: DevicePlatform.iOS, sections: [
                SettingsSection(tiles: [
                  SettingsTile.switchTile(
                    title: const Text("Enable"),
                    initialValue: controller.relay.value.active,
                    onToggle: (bool value) async {
                      controller.relay.value.active = value;
                      await RelayService().update(controller.relay.value);
                      controller.relay.refresh();
                      WebsocketService websocketService =
                          Get.find<WebsocketService>();

                      websocketService
                          .updateRelayWidget(controller.relay.value);
                      if (value &&
                          websocketService.channels[controller.relay.value.url]
                                  ?.channelStatus !=
                              RelayStatusEnum.success) {
                        websocketService.addChannel(controller.relay.value);
                        RelayService()
                            .initRelayFeeInfo([controller.relay.value]);
                      }
                      EasyLoading.showToast('Setting saved');
                    },
                  ),
                  // SettingsTile.switchTile(
                  //   title: const Text("Default relay"),
                  //   initialValue: controller.relay.value.isDefault,
                  //   description: const Text(
                  //       'It is the main relay to connect my friends.'),
                  //   onToggle: (bool value) async {
                  //     await RelayService()
                  //         .updateDefault(controller.relay.value, value);
                  //     controller.relay.value.isDefault = value;
                  //     controller.relay.refresh();
                  //     Get.find<WebsocketService>()
                  //         .updateRelayWidget(controller.relay.value);

                  //     EasyLoading.showToast('Setting saved');
                  //   },
                  // ),
                  //  SettingsTile.switchTile(
                  //   title: const Text("Write"),
                  //   initialValue: controller.relay.value.write,
                  //   onToggle: (bool value) async {
                  //     controller.relay.value.write = value;
                  //     await RelayService().update(controller.relay.value);
                  //     controller.relay.refresh();
                  //     Get.find<SettingController>()
                  //         .setRelayEnableStatus(controller.relay.value);
                  //     EasyLoading.showToast('Setting saved');
                  //   },
                  // ),
                  // SettingsTile.switchTile(
                  //   title: const Text("Read"),
                  //   initialValue: controller.relay.value.read,
                  //   description: const Text(
                  //       '1. Apply config when reconnection. \n2. The room\'s configuration will overrides this settings.'),
                  //   onToggle: (bool value) async {
                  //     controller.relay.value.read = value;
                  //     await RelayService().update(controller.relay.value);
                  //     controller.relay.refresh();
                  //     Get.find<SettingController>()
                  //         .setRelayEnableStatus(controller.relay.value);
                  //     EasyLoading.showToast('Setting saved');
                  //   },
                  // ),

                  SettingsTile(
                    title: const Text("ID"),
                    value: Text(controller.info['id'] ?? ""),
                    onPressed: (context) {
                      if (controller.info['id'] == null) return;
                      Clipboard.setData(
                          ClipboardData(text: controller.info['id']));
                      EasyLoading.showToast('Copied');
                    },
                  ),
                  SettingsTile(
                    title: const Text("pubkey"),
                    value: Flexible(
                        child: Text(
                      controller.info['pubkey'] ?? "",
                    )),
                    onPressed: (context) {
                      if (controller.info['pubkey'] == null) return;
                      Clipboard.setData(
                          ClipboardData(text: controller.info['pubkey']));
                      EasyLoading.showToast('Copied');
                    },
                  ),
                ]),
                getFeesWidget(),
                SettingsSection(
                  title: const Text('Info'),
                  tiles: [
                    SettingsTile(
                      title: const Text("contact"),
                      value: Text(controller.info['contact'] ?? ""),
                    ),
                    SettingsTile(
                      title: const Text("Name"),
                      value: Text(controller.info['name'] ?? ""),
                    ),
                    SettingsTile(
                      title: const Text("Description"),
                      value: Flexible(
                          child: Text(
                        controller.info['description'] ?? "",
                      )),
                    ),
                    SettingsTile(
                      title: const Text("NIPs"),
                      value: Flexible(
                          child: Text(
                        (controller.info['supported_nips'] ?? []).toString(),
                      )),
                    ),
                    SettingsTile(
                      title: const Text("Software"),
                      trailing: Flexible(
                        child: Text(
                          controller.info['software'] ?? "",
                        ),
                      ),
                    ),
                    SettingsTile(
                      title: const Text("Version"),
                      value: Text(controller.info['version'] ?? ""),
                    ),
                  ],
                ),
              ]))),
        ],
      ),
    );
  }

  SettingsSection getFeesWidget() {
    List<SettingsTile> list = [
      // SettingsTile(
      //     title: const Text("payments_url"),
      //     value: Text(controller.info['fees']?['payments_url'] ?? ""))
    ];
    Map<String, dynamic> fees = controller.info['fees'] ?? {};
    if (controller.info['limitation']?['payment_required'] ?? false) {
      if (fees['publication'].length == 1) {
        Map publication = fees['publication'][0];
        List<String> mints = [];
        for (var m in publication['method']['Cashu']["mints"]) {
          mints.add(m);
        }

        list.add(SettingsTile(
          title: const Text('Price'),
          value:
              Text("${publication['amount']} ${publication['unit']} / message"),
        ));
        list.add(SettingsTile(
          title: const Text('Event Kinds'),
          value: Text(publication['kinds'].toString()),
        ));
        list.add(SettingsTile(
          title: const Text('Mint'),
          value: Text(mints.join(',')),
        ));
      }
    }

    var st = SettingsTile(
      title: const Text('Price'),
      value: const Text("-"),
    );
    return SettingsSection(
        title: const Text('Fees'), tiles: list.isEmpty ? [st] : list);
  }

  @pragma('vm:entry-point')
  static Route<void> _modalBuilder(BuildContext context, Object? arguments) {
    RelayInfoController controller = Get.find<RelayInfoController>();
    return CupertinoModalPopupRoute<void>(
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(controller.relay.value.url),
          // message: const Text('Message'),
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              child: const Text('Copy'),
              onPressed: () {
                // Copy to clipboard
                Clipboard.setData(
                    ClipboardData(text: controller.relay.value.url));
                Navigator.pop(context);
              },
            ),
            CupertinoActionSheetAction(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                Get.back();
                await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return CupertinoAlertDialog(
                        title: const Text('Delete this relay?'),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () {
                              Get.back();
                            },
                            child: const Text(
                              'Cancel',
                            ),
                          ),
                          CupertinoDialogAction(
                            onPressed: () async {
                              WebsocketService websocketService =
                                  Get.find<WebsocketService>();
                              if (websocketService.channels.length == 1) {
                                EasyLoading.showToast('At least one relay');
                                return;
                              }

                              await RelayService()
                                  .delete(controller.relay.value.id);
                              websocketService
                                  .deleteRelay(controller.relay.value);

                              Get.back();
                              Get.back();
                            },
                            isDestructiveAction: true,
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          )
                        ]);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}
