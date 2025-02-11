import 'package:app/controller/setting.controller.dart';
import 'package:app/models/relay.dart';
import 'package:app/nostr-core/relay_websocket.dart';
import 'package:app/page/setting/relay_info/relay_info_bindings.dart';
import 'package:app/page/setting/relay_info/relay_info_page.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class RelaySetting extends StatefulWidget {
  const RelaySetting({super.key});

  @override
  _RelaySettingState createState() => _RelaySettingState();
}

class _RelaySettingState extends State<RelaySetting> {
  late WebsocketService ws;

  @override
  void initState() {
    ws = Get.find<WebsocketService>();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Relay Server'),
          actions: [
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return CupertinoAlertDialog(
                      title: const Text("Reconnect Relays"),
                      content: const Text(
                          "Are you sure you want to reconnect all relays?"),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text("Cancel"),
                        ),
                        CupertinoDialogAction(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            Get.find<WebsocketService>().start();
                          },
                          child: const Text("Confirm"),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(CupertinoIcons.refresh),
            ),
            IconButton(
              onPressed: addRelay,
              icon: const Icon(CupertinoIcons.add_circled),
            )
          ],
        ),
        body: Obx(() => ws.channels.values.isNotEmpty
            ? SettingsList(platform: DevicePlatform.iOS, sections: [
                SettingsSection(
                  margin: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                  tiles: ws.channels.values
                      .map((RelayWebsocket rw) => SettingsTile.navigation(
                            title: Text(rw.relay.url),
                            value: rw.relay.active
                                ? (ws.relayMessageFeeModels[rw.relay.url] !=
                                        null
                                    ? ws.relayMessageFeeModels[rw.relay.url]!
                                                .amount ==
                                            0
                                        ? const Text('free')
                                        : Text(
                                            '${ws.relayMessageFeeModels[rw.relay.url]!.amount} ${ws.relayMessageFeeModels[rw.relay.url]!.unit.name}')
                                    : const Text('free'))
                                : null,
                            leading: Icon(
                                rw.relay.isDefault ? Icons.star : Icons.circle,
                                size: rw.relay.isDefault ? 16 : 12,
                                color: getColorByStatus(rw.channelStatus)),
                            onPressed: (context) {
                              Get.to(() => const RelayInfoPage(),
                                  arguments: rw.relay,
                                  binding: RelayInfoBindings());
                            },
                          ))
                      .toList(),
                )
              ])
            : const Center(child: Text("No relay configured yet"))));
  }

  getColorByStatus(RelayStatusEnum status) {
    switch (status) {
      case RelayStatusEnum.connecting:
        return Colors.yellow;
      case RelayStatusEnum.success:
        return Colors.green;
      case RelayStatusEnum.failed:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void addRelay() {
    SettingController settingController = Get.find<SettingController>();
    Get.dialog(CupertinoAlertDialog(
      title: const Text("Add Nostr Relay"),
      content: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(top: 15),
        child: TextField(
          controller: settingController.relayTextController,
          textInputAction: TextInputAction.done,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Server url',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text("Cancel"),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () async {
            Get.back();
            var url = settingController.relayTextController.text.trim();
            if (url.startsWith("ws://") || url.startsWith("wss://")) {
              await RelayService.instance.addAndConnect(url);
              settingController.relayTextController.clear();
              return;
            } else {
              EasyLoading.showError("Please input right format relay");
              settingController.relayTextController.clear();
            }
          },
          child: const Text("Confirm"),
        ),
      ],
    ));
  }
}
