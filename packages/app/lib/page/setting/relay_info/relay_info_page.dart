import 'package:keychat/page/setting/relay_info/relay_info_controller.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/utils.dart';
import 'package:settings_ui/settings_ui.dart';

class RelayInfoPage extends GetView<RelayInfoController> {
  const RelayInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ws = Get.find<WebsocketService>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Obx(() => Text(controller.relay.value.url)),
        actions: [
          IconButton(
            onPressed: () async {
              await showCupertinoModalPopup<void>(
                context: context,
                builder: (BuildContext context) => CupertinoActionSheet(
                  title: Text(controller.relay.value.url),
                  // message: const Text('Message'),
                  actions: <CupertinoActionSheetAction>[
                    CupertinoActionSheetAction(
                      child: const Text('Copy'),
                      onPressed: () {
                        // Copy to clipboard
                        Clipboard.setData(
                          ClipboardData(text: controller.relay.value.url),
                        );
                        EasyLoading.showToast('Copied');
                        Navigator.pop(context);
                      },
                    ),
                    CupertinoActionSheetAction(
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: () async {
                        Get
                          ..back<void>()
                          ..dialog(
                            CupertinoAlertDialog(
                              title: const Text('Delete this relay?'),
                              actions: [
                                CupertinoDialogAction(
                                  onPressed: Get.back,
                                  child: const Text(
                                    'Cancel',
                                  ),
                                ),
                                CupertinoDialogAction(
                                  onPressed: () async {
                                    try {
                                      final ws = Get.find<WebsocketService>();
                                      if (ws.channels.length == 1) {
                                        EasyLoading.showToast(
                                          'No more relays left',
                                        );
                                        return;
                                      }

                                      await RelayService.instance.delete(
                                        controller.relay.value.id,
                                      );
                                      if (Get.isBottomSheetOpen ?? false) {
                                        Get.back<void>();
                                      }
                                      ws
                                          .channels[controller.relay.value.url]
                                          ?.channel
                                          ?.close();
                                      ws.channels.remove(
                                        controller.relay.value.url,
                                      );

                                      Get.back<void>();
                                      EasyLoading.showSuccess('Relay deleted');
                                    } catch (e, s) {
                                      logger.e(
                                        'Delete relay error: $e',
                                        stackTrace: s,
                                      );
                                      EasyLoading.showError(
                                        'Delete relay failed: $e',
                                      );
                                    }
                                  },
                                  isDestructiveAction: true,
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                      },
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Obx(
            () => Visibility(
              visible:
                  ws.channels[controller.relay.value.url]?.relay.errorMessage !=
                  null,
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber,
                  color: Colors.red,
                ),
                title: const Text('Error'),
                subtitle: Text(
                  ws.channels[controller.relay.value.url]?.relay.errorMessage ??
                      '',
                ),
              ),
            ),
          ),
          Obx(
            () => Expanded(
              child: SettingsList(
                platform: DevicePlatform.iOS,
                sections: [
                  SettingsSection(
                    tiles: [
                      SettingsTile.switchTile(
                        title: const Text('Enable'),
                        initialValue: controller.relay.value.active,
                        onToggle: (bool value) async {
                          controller.relay.value.active = value;
                          await RelayService.instance.update(
                            controller.relay.value,
                          );
                          controller.relay.refresh();
                          final ws = Get.find<WebsocketService>();
                          if (value) {
                            await RelayService.instance.addAndConnect(
                              controller.relay.value.url,
                            );
                          } else {
                            await ws.disableRelay(controller.relay.value);
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
                      //     await RelayService.instance
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
                      //     await RelayService.instance.update(controller.relay.value);
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
                      //     await RelayService.instance.update(controller.relay.value);
                      //     controller.relay.refresh();
                      //     Get.find<SettingController>()
                      //         .setRelayEnableStatus(controller.relay.value);
                      //     EasyLoading.showToast('Setting saved');
                      //   },
                      // ),
                      SettingsTile(
                        title: const Text('ID'),
                        value: Text(controller.info['id'] ?? ''),
                        onPressed: (context) {
                          if (controller.info['id'] == null) return;
                          Clipboard.setData(
                            ClipboardData(text: controller.info['id']),
                          );
                          EasyLoading.showToast('Copied');
                        },
                      ),
                      SettingsTile(
                        title: const Text('pubkey'),
                        value: Flexible(
                          child: Text(
                            controller.info['pubkey'] ?? '',
                          ),
                        ),
                        onPressed: (context) {
                          if (controller.info['pubkey'] == null) return;
                          Clipboard.setData(
                            ClipboardData(text: controller.info['pubkey']),
                          );
                          EasyLoading.showToast('Copied');
                        },
                      ),
                    ],
                  ),
                  getFeesWidget(),
                  SettingsSection(
                    title: const Text('Info'),
                    tiles: [
                      SettingsTile(
                        title: const Text('contact'),
                        value: Text(controller.info['contact'] ?? ''),
                      ),
                      SettingsTile(
                        title: const Text('Name'),
                        value: Text(controller.info['name'] ?? ''),
                      ),
                      SettingsTile(
                        title: const Text('Description'),
                        value: Flexible(
                          child: Text(
                            controller.info['description'] ?? '',
                          ),
                        ),
                      ),
                      SettingsTile(
                        title: const Text('NIPs'),
                        value: Flexible(
                          child: Text(
                            (controller.info['supported_nips'] ?? [])
                                .toString(),
                          ),
                        ),
                      ),
                      SettingsTile(
                        title: const Text('Software'),
                        trailing: Flexible(
                          child: Text(
                            controller.info['software'] ?? '',
                          ),
                        ),
                      ),
                      SettingsTile(
                        title: const Text('Version'),
                        value: Text(controller.info['version'] ?? ''),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SettingsSection getFeesWidget() {
    final list = <SettingsTile>[
      // SettingsTile(
      //     title: const Text("payments_url"),
      //     value: Text(controller.info['fees']?['payments_url'] ?? ""))
    ];
    final fees =
        (controller.info['fees'] ?? <String, dynamic>{})
            as Map<String, dynamic>;
    if ((controller.info['limitation']?['payment_required'] ?? false) == true) {
      if (fees['publication'].length == 1) {
        final publication = fees['publication'][0] as Map<String, dynamic>;
        final mints = <String>[];
        for (final m in (publication['method']['Cashu']['mints'] as Iterable)) {
          mints.add(m);
        }

        list.add(
          SettingsTile(
            title: const Text('Price'),
            value: Text(
              "${publication['amount']} ${publication['unit']} / message",
            ),
          ),
        );
        list.add(
          SettingsTile(
            title: const Text('Event Kinds'),
            value: Text(publication['kinds'].toString()),
          ),
        );
        list.add(
          SettingsTile(
            title: const Text('Mint'),
            value: Text(mints.join(',')),
          ),
        );
      }
    }

    final st = SettingsTile(
      title: const Text('Price'),
      value: const Text('-'),
    );
    return SettingsSection(
      title: const Text('Fees'),
      tiles: list.isEmpty ? [st] : list,
    );
  }
}
