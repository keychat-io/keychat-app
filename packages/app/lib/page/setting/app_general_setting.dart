// ignore_for_file: use_build_context_synchronously

import 'dart:io' show File, exit;

import 'package:app/global.dart';
import 'package:app/page/dbSetup/db_setting.dart';

import 'package:app/controller/home.controller.dart';
import 'package:app/page/FileExplore.dart';
import 'package:app/page/login/OnboardingPage2.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
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
    HomeController hc = Get.find<HomeController>();
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
                        clipBehavior: Clip.antiAlias,
                        shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(4))),
                        SafeArea(
                            child: Obx(() => SettingsList(
                                    platform: DevicePlatform.iOS,
                                    sections: [
                                      SettingsSection(
                                          title:
                                              const Text('Select theme mode'),
                                          tiles: [
                                            SettingsTile(
                                              onPressed: (value) async {
                                                Get.changeThemeMode(
                                                    ThemeMode.system);
                                                controller.themeMode.value =
                                                    ThemeMode.system.name;
                                                await Storage.setString(
                                                    StorageKeyString.themeMode,
                                                    ThemeMode.system.name);
                                              },
                                              title: const Text("System Mode"),
                                              trailing:
                                                  controller.themeMode.value ==
                                                          ThemeMode.system.name
                                                      ? const Icon(
                                                          Icons.done,
                                                          color: Colors.green,
                                                        )
                                                      : null,
                                            ),
                                            SettingsTile(
                                              onPressed: (value) async {
                                                Get.changeThemeMode(
                                                    ThemeMode.light);
                                                controller.themeMode.value =
                                                    ThemeMode.light.name;
                                                await Storage.setString(
                                                    StorageKeyString.themeMode,
                                                    ThemeMode.light.name);
                                              },
                                              title: const Text("Light Mode"),
                                              trailing:
                                                  controller.themeMode.value ==
                                                          ThemeMode.light.name
                                                      ? const Icon(
                                                          Icons.done,
                                                          color: Colors.green,
                                                        )
                                                      : null,
                                            ),
                                            SettingsTile(
                                              onPressed: (value) async {
                                                Get.changeThemeMode(
                                                    ThemeMode.dark);
                                                controller.themeMode.value =
                                                    ThemeMode.dark.name;
                                                await Storage.setString(
                                                    StorageKeyString.themeMode,
                                                    ThemeMode.dark.name);
                                              },
                                              title: const Text("Dark Mode"),
                                              trailing:
                                                  controller.themeMode.value ==
                                                          ThemeMode.dark.name
                                                      ? const Icon(
                                                          Icons.done,
                                                          color: Colors.green,
                                                        )
                                                      : null,
                                            ),
                                          ])
                                    ]))));
                  },
                  title: const Text("Dark Mode")),
              SettingsTile.navigation(
                leading: const Icon(CupertinoIcons.home),
                title: const Text("Startup Tab"),
                onPressed: (context) async {
                  Get.bottomSheet(
                      clipBehavior: Clip.antiAlias,
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(4))),
                      SafeArea(
                          child: Scaffold(
                              appBar: AppBar(
                                title: Text('Default startup tab'),
                              ),
                              body: Column(
                                children:
                                    hc.defaultTabConfig.entries.map((entry) {
                                  return RadioListTile<dynamic>(
                                    title: Text(entry.key),
                                    value: entry.value,
                                    groupValue: hc.defaultSelectedTab.value,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      hc.setDefaultSelectedTab(value);
                                      EasyLoading.showSuccess(
                                          'Set successfully');
                                      Get.back();
                                    },
                                  );
                                }).toList(),
                              ))));
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(CupertinoIcons.doc),
                title: const Text("App File Explore"),
                onPressed: (context) async {
                  Get.to(() => FileExplorerPage(dir: controller.appFolder),
                      id: GetPlatform.isDesktop ? GetXNestKey.setting : null);
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(CupertinoIcons.question_circle),
                title: const Text("About Keychat"),
                onPressed: (context) {
                  Get.to(() => const OnboardingPage2(),
                      id: GetPlatform.isDesktop ? GetXNestKey.setting : null);
                },
              ),
            ]),
            SettingsSection(title: const Text('Backup'), tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.dataset_outlined),
                title: const Text("Database Setting"),
                onPressed: handleDBSettting,
              )
            ]),
            dangerZone()
          ],
        ));
  }

  handleDBSettting(BuildContext context) async {
    HomeController hc = Get.find<HomeController>();
    Get.bottomSheet(
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
        SafeArea(
            child: Obx(
          () => SettingsList(platform: DevicePlatform.iOS, sections: [
            SettingsSection(title: const Text('Database Setting'), tiles: [
              SettingsTile.switchTile(
                  initialValue: hc.checkRunStatus.value,
                  description: hc.checkRunStatus.value
                      ? NoticeTextWidget.warning(
                          'Pause the chat to enable database actions.')
                      : NoticeTextWidget.warning(
                          'Use the latest chat database on your device to avoid message interruptions.'),
                  onToggle: (res) async {
                    if (!res) {
                      Get.dialog(CupertinoAlertDialog(
                        title: const Text("Stop chat?"),
                        content: const Text(
                            "You will not be able to receive and send messages while the chat is stopped."),
                        actions: <Widget>[
                          CupertinoDialogAction(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Get.back();
                            },
                          ),
                          CupertinoDialogAction(
                              isDestructiveAction: true,
                              child: const Text('Stop'),
                              onPressed: () async {
                                closeAllRelays();
                                Get.back();
                              }),
                        ],
                      ));
                      return;
                    }
                    Get.find<HomeController>().checkRunStatus.value = true;
                    Get.find<WebsocketService>().start();
                  },
                  title: Text(hc.checkRunStatus.value
                      ? 'Chat is running'
                      : 'Chat is stopped')),
              SettingsTile.navigation(
                  title: const Text('Export data'),
                  onPressed: (context) async {
                    // need check if message sending and receiving are disabled
                    // and need to set pwd to encrypt database
                    if (hc.checkRunStatus.value) {
                      EasyLoading.showError(
                          'Pause the chat to export database');
                      return;
                    }
                    _showSetEncryptionPwdDialog(context);
                  }),
            ])
          ]),
        )));
  }

  void _showSetEncryptionPwdDialog(BuildContext context) {
    TextEditingController passwordController = TextEditingController();
    TextEditingController confirmPasswordController = TextEditingController();

    Get.dialog(
      CupertinoAlertDialog(
        title: const Text("Set encryption password"),
        content: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 15),
          child: Column(
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                textInputAction: TextInputAction.next,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Get.back();
            },
            child: const Text('Cancel'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () async {
              if (passwordController.text.isNotEmpty &&
                  passwordController.text != confirmPasswordController.text) {
                EasyLoading.showError('Passwords do not match');
                return;
              }
              await Storage.setString(
                  StorageKeyString.dbBackupPwd, confirmPasswordController.text);
              Get.back();
              await Future.delayed(const Duration(microseconds: 100));
              EasyLoading.show(status: 'Exporting...');
              try {
                await DbSetting()
                    .exportDB(context, confirmPasswordController.text);
                EasyLoading.showSuccess("Export successful");
              } catch (e, s) {
                logger.e(e.toString(), error: e, stackTrace: s);
                EasyLoading.showError('Export failed: ${e.toString()}');
              } finally {
                await Future.delayed(const Duration(seconds: 2));
                EasyLoading.dismiss();
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  static _showEnterDecryptionPwdDialog(BuildContext context, File file) {
    TextEditingController passwordController = TextEditingController();

    Get.dialog(
      CupertinoAlertDialog(
        title: const Text("Enter decryption password"),
        content: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 15),
          child: Column(
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Get.back();
            },
            child: const Text('Cancel'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () async {
              if (passwordController.text.isNotEmpty) {
                try {
                  bool success = await DbSetting()
                      .importDB(context, passwordController.text, file);
                  // await Future.delayed(const Duration(microseconds: 100));
                  if (success) {
                    EasyLoading.showSuccess("Decryption successful");
                    // need to restart the app and reload database
                    // Restart.restartApp does not work?
                    // Restart.restartApp(
                    //   // Customizing the notification message only on IOS
                    //   notificationTitle: 'Restarting App',
                    //   notificationBody:
                    //       'Please tap here to open the app again.',
                    // );
                    Get.dialog(
                      CupertinoAlertDialog(
                        title: const Text('Restart Required'),
                        content: const Text(
                            'The app needs to restart to reload the database. Please restart the app manually.'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text(
                              'Exit',
                              style: TextStyle(color: Colors.red),
                            ),
                            onPressed: () {
                              exit(0); // Exit the app
                            },
                          ),
                        ],
                      ),
                    );
                  } else {
                    EasyLoading.showError('Decryption failed');
                  }
                } catch (e) {
                  EasyLoading.showError('Decryption failed');
                }
              } else {
                EasyLoading.showError('Password can not be empty');
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  static enableImportDB(BuildContext context) {
    Get.dialog(CupertinoAlertDialog(
      title: const Text("Alert"),
      content: const Text(
          'Once executed, this action will permanently delete all your local data. Proceed with caution to avoid unintended consequences.'),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text("Cancel"),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
          child: const Text("Confirm"),
          onPressed: () async {
            File? file = await DbSetting().importFile();
            if (file == null) {
              return;
            }
            _showEnterDecryptionPwdDialog(context, file);
          },
        ),
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
                  // ignore: empty_catches
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
