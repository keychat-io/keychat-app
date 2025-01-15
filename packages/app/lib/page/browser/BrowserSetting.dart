import 'package:app/page/browser/Browser_controller.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class BrowserSetting extends GetView<BrowserController> {
  const BrowserSetting({super.key});

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
                SettingsSection(
                    title: const Text('Search Engine'),
                    tiles: BrowserEngine.values
                        .map((str) => SettingsTile(
                              leading: Checkbox(
                                  value: controller.enableSearchEngine
                                      .contains(str.name),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    if (value) {
                                      controller.addSearchEngine(str.name);
                                    } else {
                                      controller.removeSearchEngine(str.name);
                                    }
                                  }),
                              title:
                                  Text(Utils.capitalizeFirstLetter(str.name)),
                            ))
                        .toList()),
                SettingsSection(
                  tiles: [
                    SettingsTile.switchTile(
                      initialValue: controller.config['enableHistory'],
                      leading: const Icon(CupertinoIcons.time),
                      title: const Text("Enable History"),
                      onToggle: (value) async {
                        await controller.setConfig('enableHistory', value);
                      },
                    ),
                    // SettingsTile.switchTile(
                    //   initialValue: controller.config['enableBookmark'],
                    //   leading: const Icon(CupertinoIcons.bookmark),
                    //   title: const Text("Show Bookmark"),
                    //   onToggle: (value) async {
                    //     await controller.setConfig('enableBookmark', value);
                    //   },
                    // ),
                    // SettingsTile.switchTile(
                    //   initialValue: controller.config['enableRecommend'],
                    //   leading: const Icon(CupertinoIcons.bookmark),
                    //   title: const Text("Show Recommended"),
                    //   onToggle: (value) async {
                    //     await controller.setConfig('enableRecommend', value);
                    //   },
                    // ),
                  ],
                ),
              ],
            )));
  }
}
