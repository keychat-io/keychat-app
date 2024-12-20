// ignore_for_file: use_build_context_synchronously

import 'dart:io' show exit;

import 'package:app/controller/home.controller.dart';
import 'package:app/main.dart';
import 'package:app/models/relay.dart';
import 'package:app/page/FileExplore.dart';
import 'package:app/page/dbSetup/db_setting.dart';
import 'package:app/page/setting/QueryReceivedEvent.dart';
import 'package:app/page/setting/UnreadMessages.dart';
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
          title: const Text('Settings'),
        ),
        body: Obx(() => SettingsList(
              platform: DevicePlatform.iOS,
              sections: [
                genreal(context, home2controller, settingController),
                SettingsSection(title: const Text('Debug Zone'), tiles: [
                  SettingsTile.navigation(
                    leading: const Icon(Icons.event),
                    title: const Text("Failed Events"),
                    onPressed: (context) async {
                      Get.to(() => const NostrEventsPage(),
                          binding: NostrEventsBindings());
                    },
                  ),
                  SettingsTile.navigation(
                    leading: const Icon(Icons.dataset_outlined),
                    title: const Text("Database Setting"),
                    onPressed: handleDBSettting,
                  ),
                  SettingsTile.navigation(
                    leading: const Icon(Icons.event),
                    title: const Text("Query Received Event"),
                    onPressed: (context) async {
                      Get.to(() => const QueryReceivedEvent());
                    },
                  ),
                  SettingsTile.navigation(
                    leading: const Icon(Icons.copy),
                    title: const Text("Unread Messages"),
                    onPressed: (context) async {
                      Get.to(() => const UnreadMessages());
                    },
                  ),
                  if (home2controller.debugModel.value || kDebugMode)
                    SettingsTile.navigation(
                      leading: const Icon(CupertinoIcons.airplane),
                      title: const Text("App File Explore"),
                      onPressed: (context) async {
                        Get.to(() =>
                            FileExplorerPage(dir: settingController.appFolder));
                      },
                    ),
                ]),
                dangerZone(settingController)
              ],
            )));
  }

  void closeAllRelays() async {
    List<Relay> relays = await RelayService.instance.getEnableRelays();
    for (Relay relay in relays) {
      relay.active = false;
      await RelayService.instance.update(relay);
    }
    await Get.find<WebsocketService>().stopListening();
    await Storage.setBool(StorageKeyString.checkRunStatus, false);
  }

  void restartAllRelays() async {
    WebsocketService websocketService = Get.find<WebsocketService>();
    List<Relay> relays = await RelayService.instance.list();
    for (Relay relay in relays) {
      relay.active = true;
      await RelayService.instance.update(relay);
      websocketService.updateRelayWidget(relay);
    }
    await Storage.setBool(StorageKeyString.checkRunStatus, true);
  }

  handleDBSettting(BuildContext context) async {
    show300hSheetWidget(
      context,
      'Database Setting',
      SettingsList(platform: DevicePlatform.iOS, sections: [
        SettingsSection(title: const Text('Database Setting'), tiles: [
          SettingsTile.switchTile(
              initialValue:
                  (await Storage.getBool(StorageKeyString.checkRunStatus) ==
                      true),
              description: NoticeTextWidget.warning(
                  'When message sending and receiving are disabled, the database export and import functions can operate without interruption.'),
              onToggle: (res) async {
                res ? restartAllRelays() : closeAllRelays();
              },
              title: const Text('Disabled sending && receiveing')),
          SettingsTile.navigation(
              title: const Text('Export database'),
              onPressed: (context) async {
                // need check if message sending and receiving are disabled
                // and need to set pwd to encrypt database
                // DbSetting().exportDB(context);
                _showSetEncryptionPwdDialog(context);
              }),
          SettingsTile.navigation(
              title: const Text('Import database'),
              onPressed: (context) async {
                // need check if message sending and receiving are disabled
                // and need to set pwd to decrypt database
                enableImportDB(context);
              }),
        ])
      ]),
    );
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
                EasyLoading.showSuccess("Success");
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

  void _showEnterDecryptionPwdDialog(BuildContext context) {
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
                      .importDB(context, passwordController.text);
                  if (success) {
                    EasyLoading.showSuccess("Decryption successful");
                    // need to reload database
                    Get.offAllNamed(Routes.root);
                    await initServices();
                  } else {
                    EasyLoading.showError('Decryption failed');
                  }
                  // Get.back();
                  // Get.back();
                } catch (e) {
                  EasyLoading.showError('Decryption failed');
                }
              } else {
                EasyLoading.showError('Password cannot be empty');
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
          onPressed: () {
            _showEnterDecryptionPwdDialog(context);
          },
        ),
      ],
    ));
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
