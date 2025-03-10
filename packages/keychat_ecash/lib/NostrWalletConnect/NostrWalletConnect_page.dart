import 'package:app/page/components.dart';
import 'package:app/page/setting/RelaySetting.dart';
import 'package:app/utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:keychat_ecash/NostrWalletConnect/NostrWalletConnectLog_page.dart';
import 'package:settings_ui/settings_ui.dart';
import './NostrWalletConnect_controller.dart';
import 'dart:async';

class NostrWalletConnectPage extends StatefulWidget {
  const NostrWalletConnectPage({super.key});

  @override
  _NostrWalletConnectPageState createState() => _NostrWalletConnectPageState();
}

class _NostrWalletConnectPageState extends State<NostrWalletConnectPage> {
  late NostrWalletConnectController controller;
  late Timer timer;
  @override
  void initState() {
    super.initState();
    controller = Get.find<NostrWalletConnectController>();
    controller.startListening();
    timer = Timer.periodic(const Duration(seconds: 2), (_) {
      controller.initConnectUri();
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NWC - NIP47'),
      ),
      body: Column(
        children: <Widget>[
          Obx(() => SwitchListTile(
                title: const Text('NWC Status'),
                subtitle: controller.subscribeAndOnlineRelays.isNotEmpty
                    ? Wrap(
                        direction: Axis.vertical,
                        children: controller.subscribeAndOnlineRelays
                            .map((value) => textSmallGray(context, value))
                            .toList())
                    : (controller.featureStatus.value
                        ? Text('None of nip47 relay is online',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.red))
                        : Text('nostr+walletconnect://')),
                value: controller.featureStatus.value,
                onChanged: (bool value) {
                  controller.setFeatureStatus(value);
                  EasyLoading.showSuccess(
                      'NostrWalletConnect is ${value ? 'enabled' : 'disabled'}');
                },
              )),
          Obx(() => controller.featureStatus.value &&
                  controller.subscribeAndOnlineRelays.isEmpty
              ? OutlinedButton(
                  onPressed: () {
                    Get.to(() => RelaySetting());
                  },
                  child: Text('Relay Setting'))
              : Container()),
          SizedBox(height: 24),
          Obx(() => controller.nwcUri.isNotEmpty &&
                  controller.featureStatus.value
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ListTile(
                    title: Text('WalletConnect URI'),
                    subtitle: textSmallGray(context, controller.nwcUri.value,
                        maxLines: 5),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: Icon(Icons.qr_code),
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
                        label: const Text('QR Code'),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        icon: Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(
                                  ClipboardData(text: controller.nwcUri.value))
                              .then((_) {
                            EasyLoading.showSuccess('Copied');
                          });
                        },
                        label: const Text('Copy'),
                      ),
                    ],
                  )
                ])
              : Container()),
          SizedBox(height: 32),
          Obx(() => controller.featureStatus.value
              ? Expanded(
                  child: SettingsList(platform: DevicePlatform.iOS, sections: [
                  SettingsSection(tiles: [
                    SettingsTile.navigation(
                      leading: const Icon(Icons.history),
                      title: const Text('Logs'),
                      value: Obx(() => Text(controller.logs.length.toString())),
                      onPressed: (context) async {
                        Get.to(() => const NostrWalletConnectLogPage());
                      },
                    ),
                    SettingsTile(
                      leading: const Icon(Icons.auto_fix_high_sharp),
                      title: const Text('Generate a new uri'),
                      onPressed: (context) async {
                        await controller.stopNwc();
                        await controller.initWallet(loadFromCache: false);
                        await controller.setFeatureStatus(true);
                      },
                    ),
                  ])
                ]))
              : Container())
        ],
      ),
    );
  }
}
