// ignore_for_file: use_build_context_synchronously

import 'dart:io' show File, exit;

import 'package:app/controller/home.controller.dart';
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
// import 'package:restart_app/restart_app.dart';

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
    HomeController hc = Get.find<HomeController>();
    List<Relay> relays = await RelayService.instance.getEnableRelays();
    for (Relay relay in relays) {
      relay.active = false;
      await RelayService.instance.update(relay);
    }
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
                      'When message sending and receiving are disabled, the database export and import functions can operate without interruption.'),
                  onToggle: (res) async {
                    res ? closeAllRelays() : restartAllRelays();
                  },
                  title: const Text('Disabled sending && receiveing')),
              SettingsTile.navigation(
                  title: const Text('Export data'),
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
