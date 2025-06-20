import 'package:app/global.dart';
import 'package:app/nostr-core/relay_websocket.dart';
import 'package:app/page/setting/relay_info/relay_info_bindings.dart';
import 'package:app/page/setting/relay_info/relay_info_page.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:flutter/cupertino.dart' hide ConnectionState;
import 'package:flutter/material.dart' hide ConnectionState;
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
  late TextEditingController relayTextController;

  @override
  void initState() {
    super.initState();
    relayTextController = TextEditingController(text: "wss://");
    ws = Get.find<WebsocketService>();
    ws.channels.refresh();
  }

  @override
  void dispose() {
    relayTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Message Relay'),
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
                          isDefaultAction: true,
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
                                color: ws.getColorByState(
                                    rw.channel?.connection.state)),
                            onPressed: (context) {
                              Get.to(() => const RelayInfoPage(),
                                  binding: RelayInfoBindings(rw.relay),
                                  id: GetPlatform.isDesktop
                                      ? GetXNestKey.setting
                                      : null);
                            },
                          ))
                      .toList(),
                )
              ])
            : const Center(child: Text("No relay configured yet"))));
  }

  void addRelay() {
    Get.dialog(CupertinoAlertDialog(
      title: const Text("Add Nostr Relay"),
      content: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(top: 15),
        child: TextField(
          controller: relayTextController,
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
            var url = relayTextController.text.trim();
            if (url.startsWith("ws://") || url.startsWith("wss://")) {
              await RelayService.instance.addAndConnect(url);
              relayTextController.clear();
              return;
            } else {
              EasyLoading.showError("Please input right format relay");
              relayTextController.clear();
            }
          },
          child: const Text("Confirm"),
        ),
      ],
    ));
  }
}
