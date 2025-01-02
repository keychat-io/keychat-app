// ignore_for_file: use_build_context_synchronously

import 'dart:io' show File, exit;

import 'package:app/controller/home.controller.dart';
import 'package:app/models/relay.dart';
import 'package:app/page/FileExplore.dart';
import 'package:app/page/dbSetup/db_setting.dart';
import 'package:app/page/login/OnboardingPage2.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/relay.service.dart';
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
import '../components.dart';
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
                    'Keychat is a chat app, built on Bitcoin Ecash, Nostr Protocol and Signal Protocol and MLS Protocol.'),
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

  void restartAllRelays() async {
    HomeController hc = Get.find<HomeController>();
    WebsocketService websocketService = Get.find<WebsocketService>();
    List<Relay> relays = await RelayService.instance.list();
    for (Relay relay in relays) {
      relay.active = true;
      await RelayService.instance.update(relay);
      websocketService.updateRelayWidget(relay);
    }
    hc.checkRunStatus.value = true;
  }

  handleDBSettting(BuildContext context) async {
    HomeController hc = Get.find<HomeController>();
    show300hSheetWidget(
        context,
        'Database Setting',
        Obx(
          () => SettingsList(platform: DevicePlatform.iOS, sections: [
            SettingsSection(title: const Text('Database Setting'), tiles: [
              SettingsTile.switchTile(
                  initialValue: !hc.checkRunStatus.value,
                  description: NoticeTextWidget.warning(
                      'When message sending and receiving are disabled, the data export and import functions can operate without interruption.'),
                  onToggle: (res) async {
                    res ? closeAllRelays() : restartAllRelays();
                  },
                  title: const Text('Disabled sending && receiveing')),
              SettingsTile.navigation(
                  title: const Text('Export data'),
                  description: NoticeTextWidget.warning(
                      'We strongly recommend that you stop sending and receiving messages after exporting the data, unless you import it on another device.'),
                  onPressed: (context) async {
                    // need check if message sending and receiving are disabled
                    // and need to set pwd to encrypt database
                    if (hc.checkRunStatus.value) {
                      EasyLoading.showError(
                          'Please disabled sending && receiveing');
                      return;
                    }
                    _showSetEncryptionPwdDialog(context);
                  }),
              SettingsTile.navigation(
                  title: const Text('Import data'),
                  description: NoticeTextWidget.warning(
                      'You must import the latest data. Otherwise, the Signal session may be interrupted, and sending and receiving messages may not function properly.'),
                  onPressed: (context) async {
                    // need check if message sending and receiving are disabled
                    // and need to set pwd to decrypt database
                    if (hc.checkRunStatus.value) {
                      EasyLoading.showError(
                          'Please disabled sending && receiveing');
                      return;
                    }
                    enableImportDB(context);
                  }),
            ])
          ]),
        ));
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
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (passwordController.text.isNotEmpty &&
                  passwordController.text == confirmPasswordController.text) {
                await Storage.setString(StorageKeyString.dbBackupPwd,
                    confirmPasswordController.text);
                EasyLoading.showSuccess("Password successfully set");
                Get.back();
                await Future.delayed(const Duration(microseconds: 100));
                DbSetting().exportDB(context, confirmPasswordController.text);
              } else {
                EasyLoading.showError('Passwords do not match');
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showEnterDecryptionPwdDialog(BuildContext context, File file) {
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
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (passwordController.text.isNotEmpty) {
                try {
                  await Future.delayed(const Duration(microseconds: 100));
                  bool success = await DbSetting()
                      .importDB(context, passwordController.text, file);
                  // await Future.delayed(const Duration(microseconds: 100));
                  if (success) {
                    await Future.delayed(const Duration(microseconds: 100));
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

  enableImportDB(BuildContext context) {
    Get.dialog(CupertinoAlertDialog(
      title: const Text(
        "Alert",
        style: TextStyle(color: Colors.red),
      ),
      content: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 15),
          child: const Text(
              'Once executed, this action will permanently delete all your local data. Proceed with caution to avoid unintended consequences.')),
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
              EasyLoading.showError('status: No file select',
                  duration: const Duration(seconds: 3));
              logger.e("No file select.");
              return;
            }
            _showEnterDecryptionPwdDialog(context, file);
          },
        ),
      ],
    ));
  }

  dangerZone() {
    return SettingsSection(title: const Text("Danger Zone"), tiles: [
      SettingsTile(
          leading: const Icon(
            CupertinoIcons.trash,
            color: Colors.red,
          ),
          title: const Text("Reset APP", style: TextStyle(color: Colors.red)),
          onPressed: (context) {
            Get.dialog(deleteAccount(context, true));
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
          child: const Text('Cancel'),
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
                await DBProvider.instance.deleteAll();
                await deleteAllFolder(); // delete all files
                await Get.find<WebsocketService>().stopListening();
                await Storage.clearAll();
                await SecureStorage.instance.clearAll();
                Storage.setInt(StorageKeyString.onboarding, 0);
                FirebaseMessaging.instance.deleteToken();
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
    );
  }
}
