import 'package:app/global.dart';
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
      body: Obx(
        () => SettingsList(
          platform: DevicePlatform.iOS,
          sections: [
            if (identities.isNotEmpty)
              SettingsSection(
                title: const Text('Enable Browser ID'),
                tiles: identities
                    .map(
                      (identity) => SettingsTile.navigation(
                        leading: Utils.getAvatarByIdentity(identity),
                        title: Text(
                          identity.displayName.length > 8
                              ? '${identity.displayName.substring(0, 8)}...'
                              : identity.displayName,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        value: Text(getPublicKeyDisplay(identity.npub)),
                        onPressed: (context) {
                          Get.to(
                            () => BrowserConnectedWebsite(identity),
                            id: GetPlatform.isDesktop
                                ? GetXNestKey.setting
                                : null,
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  title: const Text('Search Engine'),
                  leading: const Icon(Icons.search),
                  value: Text(controller.defaultSearchEngineObx.value),
                  onPressed: (context) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return RadioGroup<String>(
                          groupValue: controller.defaultSearchEngineObx.value,
                          onChanged: (value) {
                            if (value == null) return;
                            controller.defaultSearchEngineObx.value = value;
                            Storage.setString(
                              'defaultSearchEngine',
                              value,
                            );
                            EasyLoading.showSuccess('Success');
                            Get.back<void>();
                          },
                          child: SimpleDialog(
                            title: const Text('Select Search Engine'),
                            children: BrowserEngine.values
                                .map(
                                  (str) => ListTile(
                                    leading: Radio<String>(
                                      value: str.name,
                                    ),
                                    title: Text(
                                      Utils.capitalizeFirstLetter(
                                        str.name,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  initialValue: controller.config['autoSignEvent'] ?? true,
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('Auto Sign Event'),
                  onToggle: (value) async {
                    await controller.setConfig('autoSignEvent', value);
                    EasyLoading.showSuccess('Success');
                  },
                ),
                SettingsTile.switchTile(
                  initialValue: controller.config['enableHistory'] ?? true,
                  leading: const Icon(CupertinoIcons.time),
                  title: const Text('Enable History'),
                  onToggle: (value) async {
                    await controller.setConfig('enableHistory', value);
                    EasyLoading.showSuccess('Success');
                  },
                ),
                if (GetPlatform.isMobile)
                  SettingsTile.navigation(
                    leading: const Icon(CupertinoIcons.heart),
                    title: const Text('KeepAlive Hosts'),
                    onPressed: (context) {
                      Get.to(KeepAliveHosts.new);
                    },
                  ),
                if (controller.config['enableHistory'] == true)
                  SettingsTile.navigation(
                    title: const Text('Auto-delete'),
                    value: Text(
                      "${controller.config['historyRetentionDays'] ?? 30} ${controller.config['historyRetentionDays'] == 1 ? 'day' : 'days'}",
                    ),
                    leading: const Icon(CupertinoIcons.delete),
                    onPressed: (context) async {
                      final selectedDays = await showDialog<int>(
                        context: context,
                        builder: (BuildContext context) {
                          return RadioGroup<int>(
                            groupValue: controller
                                    .config['historyRetentionDays'] as int? ??
                                30,
                            onChanged: selectRetentionPeriod,
                            child: SimpleDialog(
                              title: const Text('Select Retention Period'),
                              children: [1, 7, 30].map((days) {
                                return RadioListTile<int>(
                                  title: Text(
                                    '$days ${days == 1 ? 'Day' : 'Days'}',
                                  ),
                                  value: days,
                                );
                              }).toList(),
                            ),
                          );
                        },
                      );

                      if (selectedDays != null) {
                        await controller.setConfig(
                          'historyRetentionDays',
                          selectedDays,
                        );
                      }
                    },
                  ),
                if (GetPlatform.isMobile)
                  SettingsTile.switchTile(
                    initialValue: controller.showAppBar(),
                    leading: const Icon(Icons.view_headline),
                    title: const Text('Show AppBar'),
                    onToggle: (value) async {
                      await controller.setConfig('showAppBar', value);
                      EasyLoading.showSuccess('Success');
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> init() async {
    final list = await IdentityService.instance.getEnableBrowserIdentityList();
    setState(() {
      identities = list;
    });
  }

  Future<void> selectRetentionPeriod(Object? value) async {
    if (value == null) return;
    await controller.setConfig('historyRetentionDays', value as int);
    await EasyLoading.showSuccess('Success');
    await controller.deleteOldHistories();
    Get.back(result: value);
  }
}
