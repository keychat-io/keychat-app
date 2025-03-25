// ignore_for_file: use_build_context_synchronously

import 'dart:io' show exit;

import 'package:app/controller/home.controller.dart';
import 'package:app/page/FileExplore.dart';
import 'package:app/page/login/OnboardingPage2.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:settings_ui/settings_ui.dart';
// import 'package:restart_app/restart_app.dart';

import '../../controller/setting.controller.dart';
import '../../models/db_provider.dart';
import '../../service/file_util.dart';
import '../../service/storage.dart';
import '../routes.dart';

class AppGeneralSetting extends GetView<SettingController> {
  const AppGeneralSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('App Settings'),
        ),
        body: SettingsList(
          platform: DevicePlatform.iOS,
          sections: [
            SettingsSection(tiles: [
              SettingsTile.navigation(
                  leading: const Icon(CupertinoIcons.brightness),
                  onPressed: (context) async {
                    Get.bottomSheet(
                        SettingsList(platform: DevicePlatform.iOS, sections: [
                      SettingsSection(
                          title: const Text('Select theme mode'),
                          tiles: [
                            SettingsTile(
                              onPressed: (value) async {
                                Get.changeThemeMode(ThemeMode.system);
                                controller.themeMode.value =
                                    ThemeMode.system.name;
                                await Storage.setString(
                                    StorageKeyString.themeMode,
                                    ThemeMode.system.name);
                              },
                              title: const Text("System Mode"),
                              trailing: controller.themeMode.value ==
                                      ThemeMode.system.name
                                  ? const Icon(
                                      Icons.done,
                                      color: Colors.green,
                                    )
                                  : null,
                            ),
                            SettingsTile(
                              onPressed: (value) async {
                                Get.changeThemeMode(ThemeMode.light);
                                controller.themeMode.value =
                                    ThemeMode.light.name;
                                await Storage.setString(
                                    StorageKeyString.themeMode,
                                    ThemeMode.light.name);
                              },
                              title: const Text("Light Mode"),
                              trailing: controller.themeMode.value ==
                                      ThemeMode.light.name
                                  ? const Icon(
                                      Icons.done,
                                      color: Colors.green,
                                    )
                                  : null,
                            ),
                            SettingsTile(
                              onPressed: (value) async {
                                Get.changeThemeMode(ThemeMode.dark);
                                controller.themeMode.value =
                                    ThemeMode.dark.name;
                                await Storage.setString(
                                    StorageKeyString.themeMode,
                                    ThemeMode.dark.name);
                              },
                              title: const Text("Dark Mode"),
                              trailing: controller.themeMode.value ==
                                      ThemeMode.dark.name
                                  ? const Icon(
                                      Icons.done,
                                      color: Colors.green,
                                    )
                                  : null,
                            ),
                          ])
                    ]));
                  },
                  title: const Text("Dark Mode")),
              SettingsTile.navigation(
                leading: const Icon(CupertinoIcons.doc),
                title: const Text("App File Explore"),
                onPressed: (context) async {
                  Get.to(() => FileExplorerPage(dir: controller.appFolder));
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(CupertinoIcons.question_circle),
                title: const Text("About Keychat"),
                description: const Text(
                    'Keychat is a chat app, built on Bitcoin Ecash, Nostr Protocol and Signal / MLS Protocol.'),
                onPressed: (context) {
                  Get.to(() => const OnboardingPage2());
                },
              ),
            ]),
            dangerZone()
          ],
        ));
  }

  void closeAllRelays() async {
    HomeController hc = Get.find<HomeController>();
    await Get.find<WebsocketService>().stopListening();
    hc.checkRunStatus.value = false;
  }

  dangerZone() {
    return SettingsSection(tiles: [
      SettingsTile.navigation(
          leading: const Icon(
            CupertinoIcons.trash,
            color: Colors.red,
          ),
          title: const Text("Logout", style: TextStyle(color: Colors.red)),
          onPressed: deleteAccount)
    ]);
  }

  deleteAccount(BuildContext context) {
    return Get.dialog(CupertinoAlertDialog(
      title: const Text("Logout All Identity?"),
      content: const Text(
          "Please make sure you have backed up your seed phrase and contacts. This cannot be undone."),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text('Cancel'),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Logout'),
            onPressed: () async {
              EasyLoading.show(status: 'Processing...');
              try {
                await DBProvider.instance.deleteAll();
                await deleteAllFolder(); // delete all files
                await Get.find<WebsocketService>().stopListening();
                await Storage.clearAll();
                await SecureStorage.instance.clearAll();
                Storage.setInt(StorageKeyString.onboarding, 0);
                try {
                  await FirebaseMessaging.instance.deleteToken();
                } catch (e) {}
                NotifyService.clearAll();
                Get.offAllNamed(Routes.login);
              } catch (e, s) {
                EasyLoading.showError(e.toString(),
                    duration: const Duration(seconds: 2));
                logger.e('reset all', error: e, stackTrace: s);
              } finally {
                await Future.delayed(const Duration(seconds: 2));
                EasyLoading.dismiss();
                kReleaseMode && exit(0);
              }
            }),
      ],
    ));
  }
}
