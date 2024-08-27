// ignore_for_file: use_build_context_synchronously

import 'dart:io' show exit;

import 'package:app/controller/home.controller.dart';

import 'package:app/page/FileExplore.dart';
import 'package:app/service/secure_storage.dart';

import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

import '../../controller/setting.controller.dart';
import '../../models/db_provider.dart';
import '../../service/file_util.dart';
import '../../service/storage.dart';
import '../components.dart';
import '../routes.dart';
import 'NostrEvents/NostrEvents_bindings.dart';
import 'NostrEvents/NostrEvents_page.dart';

class MoreSetting extends StatelessWidget {
  const MoreSetting({super.key});

  @override
  Widget build(BuildContext context) {
    HomeController home2controller = Get.find<HomeController>();
    SettingController settingController = Get.find<SettingController>();
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Settings',
          ),
        ),
        body: Obx(() => SettingsList(
              platform: DevicePlatform.iOS,
              sections: [
                genreal(context, home2controller, settingController),
                SettingsSection(tiles: [
                  SettingsTile.navigation(
                    leading: const Icon(Icons.event),
                    title: const Text("Received Nostr Events"),
                    onPressed: (context) async {
                      Get.to(() => const NostrEventsPage(),
                          binding: NostrEventsBindings());
                    },
                  )
                ]),
                if (home2controller.debugModel.value || kDebugMode)
                  SettingsSection(tiles: [
                    SettingsTile.navigation(
                      leading: const Icon(CupertinoIcons.airplane),
                      title: const Text("App File Explore"),
                      onPressed: (context) async {
                        Get.to(() =>
                            FileExplorerPage(dir: settingController.appFolder));
                      },
                    )
                  ]),
                dangerZone(settingController)
              ],
            )));
  }

  genreal(BuildContext buildContext, HomeController hc,
      SettingController settingController) {
    return SettingsSection(tiles: [
      SettingsTile.navigation(
          leading: const Icon(CupertinoIcons.brightness),
          onPressed: (context) async {
            show300hSheetWidget(
                buildContext,
                'Dark Mode',
                Obx(() => SettingsList(
                    platform: DevicePlatform.iOS,
                    sections: [selectMode(hc, settingController)])));
          },
          title: const Text("Dark Mode")),
      SettingsTile.navigation(
        leading: const Icon(Icons.verified_outlined),
        title: const Text("App Version"),
        value: textP(settingController.appVersion.value),
        onPressed: (context) {},
      ),

      // SettingsTile.navigation(
      //   leading: const Icon(CupertinoIcons.color_filter),
      //   title: const Text("Why Keychat?"),
      //   onPressed: (context) {
      //     showModalBottomSheetKeyChatFetures(context);
      //   },
      // ),
    ]);
  }

  selectMode(
      HomeController home2controller, SettingController settingController) {
    return SettingsSection(title: const Text('Select theme mode'), tiles: [
      SettingsTile(
        onPressed: (value) async {
          Get.changeThemeMode(ThemeMode.system);
          settingController.themeMode.value = ThemeMode.system.name;
          await Storage.setString(
              StorageKeyString.themeMode, ThemeMode.system.name);
        },
        title: const Text("System Mode"),
        trailing: settingController.themeMode.value == ThemeMode.system.name
            ? const Icon(
                Icons.done,
                color: Colors.green,
              )
            : null,
      ),
      SettingsTile(
        onPressed: (value) async {
          Get.changeThemeMode(ThemeMode.light);
          settingController.themeMode.value = ThemeMode.light.name;
          await Storage.setString(
              StorageKeyString.themeMode, ThemeMode.light.name);
        },
        title: const Text("Light Mode"),
        trailing: settingController.themeMode.value == ThemeMode.light.name
            ? const Icon(
                Icons.done,
                color: Colors.green,
              )
            : null,
      ),
      SettingsTile(
        onPressed: (value) async {
          Get.changeThemeMode(ThemeMode.dark);
          settingController.themeMode.value = ThemeMode.dark.name;
          await Storage.setString(
              StorageKeyString.themeMode, ThemeMode.dark.name);
        },
        title: const Text("Dark Mode"),
        trailing: settingController.themeMode.value == ThemeMode.dark.name
            ? const Icon(
                Icons.done,
                color: Colors.green,
              )
            : null,
      ),
    ]);
  }

  dangerZone(SettingController settingController) {
    return SettingsSection(title: const Text("Danger Zone"), tiles: [
      SettingsTile(
          leading: const Icon(
            CupertinoIcons.trash,
            color: Colors.red,
          ),
          title: const Text("Reset APP", style: TextStyle(color: Colors.red)),
          onPressed: (context) {
            showDialog<String>(
                context: context,
                builder: (BuildContext context) =>
                    deleteAccount(context, true));
          })
    ]);
  }

  Widget deleteAccount(BuildContext context, bool deleteAll) {
    return CupertinoAlertDialog(
      title: const Text("Reset All?"),
      content: const Text(
          "Please make sure you have backed up your seed phrase and contacts. This cannot be undone."),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text(
            'Cancel',
          ),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(
              deleteAll ? 'Reset and Exit' : 'Delete',
            ),
            onPressed: () async {
              EasyLoading.show(status: 'Processing...');
              try {
                await DBProvider().deleteAll();
                await deleteAllFolder(); // delete all files
                await Get.find<WebsocketService>().stopListening();
                await Storage.clearAll();
                await SecureStorage.instance.clearAll();
                Storage.setInt(StorageKeyString.onboarding, 0);
                EasyLoading.dismiss();
                Get.offAllNamed(Routes.login);
              } catch (e, s) {
                logger.e('reset all', error: e, stackTrace: s);
              } finally {
                kReleaseMode && exit(0);
              }
            }),
      ],
    );
  }
}
