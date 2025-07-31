import 'package:app/models/identity.dart';
import 'package:app/page/browser/BrowserConnectedWebsite.dart';
import 'package:app/page/browser/KeepAliveHosts.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class BrowserSetting extends StatefulWidget {
  const BrowserSetting({super.key});

  @override
  _BrowserSettingState createState() => _BrowserSettingState();
}

class _BrowserSettingState extends State<BrowserSetting> {
  late MultiWebviewController controller;
  List<Identity> identities = [];
  @override
  void initState() {
    super.initState();
    controller = Get.find<MultiWebviewController>();
    init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Browser Settings'),
          centerTitle: true,
        ),
        body: Obx(() => SettingsList(
              platform: DevicePlatform.iOS,
              sections: [
                if (identities.isNotEmpty)
                  SettingsSection(
                      title: const Text('Enable Browser ID'),
                      tiles: identities
                          .map((identity) => SettingsTile.navigation(
                              leading: Utils.getRandomAvatar(
                                  identity.secp256k1PKHex,
                                  height: 30,
                                  width: 30),
                              title: Text(
                                identity.displayName.length > 8
                                    ? "${identity.displayName.substring(0, 8)}..."
                                    : identity.displayName,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              value: Text(getPublicKeyDisplay(identity.npub)),
                              onPressed: (context) {
                                Get.to(() => BrowserConnectedWebsite(identity));
                              }))
                          .toList()),
                SettingsSection(
                    title: const Text('Default Search Engine'),
                    tiles: BrowserEngine.values
                        .map((str) => SettingsTile(
                              leading: Radio<String>(
                                  value: str.name,
                                  groupValue:
                                      controller.defaultSearchEngineObx.value,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    controller.defaultSearchEngineObx.value =
                                        value;
                                    Storage.setString(
                                        'defaultSearchEngine', value);
                                    EasyLoading.showSuccess('Success');
                                  }),
                              title:
                                  Text(Utils.capitalizeFirstLetter(str.name)),
                            ))
                        .toList()),
                SettingsSection(
                  tiles: [
                    SettingsTile.switchTile(
                      initialValue: controller.config['autoSignEvent'] ?? true,
                      leading: const Icon(Icons.auto_awesome),
                      title: const Text("Auto Sign Event"),
                      onToggle: (value) async {
                        await controller.setConfig('autoSignEvent', value);
                        EasyLoading.showSuccess('Success');
                      },
                    ),
                    SettingsTile.switchTile(
                      initialValue: controller.config['enableHistory'],
                      leading: const Icon(CupertinoIcons.time),
                      title: const Text("Enable History"),
                      onToggle: (value) async {
                        await controller.setConfig('enableHistory', value);
                        EasyLoading.showSuccess('Success');
                      },
                    ),
                    if (GetPlatform.isMobile)
                      SettingsTile.navigation(
                        leading: const Icon(CupertinoIcons.heart),
                        title: const Text("KeepAlive Hosts"),
                        onPressed: (context) {
                          Get.to(() => KeepAliveHosts());
                        },
                      ),
                    if (controller.config['enableHistory'])
                      SettingsTile.navigation(
                        title: const Text("Auto-delete"),
                        value: Text(
                            "${controller.config['historyRetentionDays'] ?? 30} ${controller.config['historyRetentionDays'] == 1 ? 'day' : 'days'}"),
                        leading: const Icon(CupertinoIcons.delete),
                        onPressed: (context) async {
                          int? selectedDays = await showDialog<int>(
                            context: context,
                            builder: (BuildContext context) {
                              return SimpleDialog(
                                title: const Text('Select Retention Period'),
                                children: [1, 7, 30].map((days) {
                                  return RadioListTile<int>(
                                    title: Text(
                                        '$days ${days == 1 ? 'Day' : 'Days'}'),
                                    value: days,
                                    groupValue: controller
                                            .config['historyRetentionDays'] ??
                                        30,
                                    onChanged: selectRetentionPeriod,
                                  );
                                }).toList(),
                              );
                            },
                          );

                          if (selectedDays != null) {
                            await controller.setConfig(
                                'historyRetentionDays', selectedDays);
                          }
                        },
                      ),
                  ],
                ),
              ],
            )));
  }

  Future init() async {
    var list = await IdentityService.instance.getEnableBrowserIdentityList();
    setState(() {
      identities = list;
    });
  }

  selectRetentionPeriod(int? value) async {
    if (value == null) return;
    controller.setConfig('historyRetentionDays', value);
    EasyLoading.showSuccess('Success');
    await controller.deleteOldHistories();
    Get.back();
  }
}
