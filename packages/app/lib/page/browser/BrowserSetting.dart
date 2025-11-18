import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:keychat/global.dart';
import 'package:keychat/models/identity.dart';
import 'package:keychat/page/browser/BrowserConnectedWebsite.dart';
import 'package:keychat/page/browser/KeepAliveHosts.dart';
import 'package:keychat/page/browser/MultiWebviewController.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat/utils.dart';
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
  bool showFAB = true;
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
                title: const Text('Enabled Browser ID'),
                tiles: identities
                    .map(
                      (identity) => SettingsTile.navigation(
                        leading: Utils.getAvatarByIdentity(identity, size: 32),
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
                if (kDebugMode)
                  SettingsTile.switchTile(
                    initialValue:
                        controller.config['adBlockEnabled'] as bool? ?? true,
                    leading: const Icon(Icons.block),
                    title: const Text('AdBlock'),
                    description: const Text('Block ads and trackers by DNS'),
                    onToggle: (value) async {
                      await controller.setConfig('adBlockEnabled', value);
                      EasyLoading.showSuccess('Success');
                    },
                  ),
                SettingsTile.switchTile(
                  initialValue:
                      controller.config['autoSignEvent'] as bool? ?? true,
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('Auto Sign Event'),
                  onToggle: (value) async {
                    await controller.setConfig('autoSignEvent', value);
                    EasyLoading.showSuccess('Success');
                  },
                ),
                SettingsTile.switchTile(
                  initialValue:
                      controller.config['enableHistory'] as bool? ?? true,
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
                            groupValue:
                                controller.config['historyRetentionDays']
                                    as int? ??
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
              ],
            ),
            if (GetPlatform.isMobile)
              SettingsSection(
                tiles: [
                  SettingsTile.switchTile(
                    initialValue: showFAB,
                    leading: const Icon(CupertinoIcons.circle_fill),
                    title: const Text('Floating Action Button'),
                    onToggle: (value) async {
                      await controller.setConfig('showFAB', value);
                      setState(() {
                        showFAB = value;
                      });
                      EasyLoading.showSuccess('Success');
                    },
                  ),
                  SettingsTile.navigation(
                    leading: const Icon(CupertinoIcons.arrow_left_right),
                    title: const Text('Position'),
                    value: Text(
                      controller.config['fabPosition'] == 'left'
                          ? 'Left'
                          : 'Right',
                    ),
                    onPressed: (context) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return RadioGroup<String>(
                            groupValue:
                                controller.config['fabPosition'] as String? ??
                                'right',
                            onChanged: (value) async {
                              if (value == null) return;
                              await controller.setConfig('fabPosition', value);
                              EasyLoading.showSuccess('Success');
                              Get.back<void>();
                            },
                            child: const SimpleDialog(
                              title: Text('Select Position'),
                              children: [
                                ListTile(
                                  leading: Radio<String>(
                                    value: 'left',
                                  ),
                                  title: Text('Left'),
                                ),
                                ListTile(
                                  leading: Radio<String>(
                                    value: 'right',
                                  ),
                                  title: Text('Right'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
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
    final fab = controller.showFAB();
    setState(() {
      showFAB = fab;
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
