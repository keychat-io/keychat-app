import 'package:app/controller/setting.controller.dart';
import 'package:app/models/embedded/relay_file_fee.dart';
import 'package:app/models/relay.dart';
import 'package:app/page/components.dart';
import 'package:app/service/file.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class KeychatS3Protocol extends StatefulWidget {
  const KeychatS3Protocol({super.key});

  @override
  _KeychatS3ProtocolState createState() => _KeychatS3ProtocolState();
}

class _KeychatS3ProtocolState extends State<KeychatS3Protocol> {
  RelayFileFee? relayFileFee;
  SettingController settingController = Get.find<SettingController>();
  WebsocketService ws = Get.find<WebsocketService>();
  bool isInit = false;
  String defaultFileServer = 'Loading';

  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    String data = settingController.defaultFileServer.value;
    RelayFileFee? fuc = await RelayService.instance.initRelayFileFeeModel(data);
    if (fuc != null) {
      ws.relayFileFeeModels[data] = fuc;
    }
    setState(() {
      defaultFileServer = data;
      relayFileFee = fuc;
      isInit = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: isInit
            ? SettingsList(platform: DevicePlatform.iOS, sections: [
                SettingsSection(
                  title: const Text('Selected Relay'),
                  tiles: [
                    SettingsTile.navigation(
                      title: const Text('File Server'),
                      value: Text(Uri.parse(defaultFileServer).host),
                      description: const Text(
                          'You need to pay Ecash to the file server for storing your encrypted file.'),
                      onPressed: (context) async {
                        List<Relay> relays =
                            await RelayService.instance.getEnableRelays();
                        Get.bottomSheet(
                            clipBehavior: Clip.antiAlias,
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(4))),
                            SettingsList(
                                platform: DevicePlatform.iOS,
                                sections: [
                                  SettingsSection(
                                      title: const Text('Select Media Server'),
                                      tiles: relays
                                          .map(
                                            (Relay relay) => SettingsTile(
                                              onPressed: (context) async {
                                                EasyLoading.show(
                                                    status: 'Loading...');
                                                await settingController
                                                    .setDefaultRelayFileServer(
                                                        relay.url);
                                                await _init();
                                                EasyLoading.showSuccess(
                                                    'Success');
                                                Get.back();
                                              },
                                              title: ListTile(
                                                title: Text(relay.url),
                                                subtitle: Text(
                                                    getFeeString(relay.url)),
                                              ),
                                              trailing:
                                                  relay.url == defaultFileServer
                                                      ? const Icon(
                                                          Icons.done,
                                                          color: Colors.green,
                                                        )
                                                      : null,
                                            ),
                                          )
                                          .toList())
                                ]));
                      },
                    ),
                  ],
                ),
                SettingsSection(
                  tiles: [
                    if (isInit == true && (relayFileFee?.mints ?? []).isEmpty)
                      SettingsTile(
                        leading: const Icon(Icons.error, color: Colors.red),
                        title: const Text(
                          'Upload File: Not Supported',
                          style: TextStyle(color: Colors.red),
                        ),
                        description:
                            const Text('Please try another file server'),
                      ),
                    if (isInit == true &&
                        (relayFileFee?.mints ?? []).isNotEmpty)
                      SettingsTile(
                          title: const Text('Allowed Mint'),
                          value: Text((relayFileFee?.mints ?? []).join(','))),
                    if (isInit == true &&
                        (relayFileFee?.mints ?? []).isNotEmpty)
                      SettingsTile(
                        title: const Text('MaxSize'),
                        value: Text(FileService.instance
                            .getFileSizeDisplay(relayFileFee?.maxSize ?? 0)),
                      ),
                    if (isInit == true &&
                        (relayFileFee?.mints ?? []).isNotEmpty)
                      SettingsTile(
                        title: const Text('Expired'),
                        value: Text(relayFileFee?.expired ?? '-'),
                      ),
                  ],
                ),
                if ((relayFileFee?.prices ?? []).isNotEmpty)
                  SettingsSection(
                      title: const Text('Price'),
                      tiles: (relayFileFee?.prices ?? [])
                          .map((price) => SettingsTile(
                                title: Text(
                                    '${FileService.instance.getFileSizeDisplay(price['min'])} < size < ${FileService.instance.getFileSizeDisplay(price['max'])}'),
                                value: Text(
                                    '${price['price']} ${relayFileFee?.unit ?? 'sat'}'),
                              ))
                          .toList())
              ])
            : pageLoadingSpinKit());
  }

  String getFeeString(String relay) {
    RelayFileFee? fuc = ws.relayFileFeeModels[relay];
    if (fuc == null) return '-';
    if (fuc.prices.isEmpty) return '-';
    return 'Fee: ${fuc.prices[0]['price']} ${fuc.unit}';
  }
}
