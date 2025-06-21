import 'package:app/app.dart';
import 'package:app/controller/setting.controller.dart';
import 'package:app/models/embedded/relay_file_fee.dart';
import 'package:app/page/components.dart';
import 'package:app/service/file.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:flutter/material.dart';
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
  String defaultFileServer = KeychatGlobal.defaultFileServer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    RelayFileFee? fuc =
        await RelayService.instance.initRelayFileFeeModel(defaultFileServer);
    if (fuc != null) {
      ws.setRelayFileFeeModel(defaultFileServer, fuc);
    }
    setState(() {
      relayFileFee = fuc;
      isInit = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(KeychatGlobal.defaultFileServer)),
        body: isInit
            ? SettingsList(platform: DevicePlatform.iOS, sections: [
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
    RelayFileFee? fuc = ws.getRelayFileFeeModel(relay);
    if (fuc == null) return '-';
    if (fuc.prices.isEmpty) return '-';
    return 'Fee: ${fuc.prices[0]['price']} ${fuc.unit}';
  }
}
