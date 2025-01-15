// ignore_for_file: use_build_context_synchronously

import 'dart:io' show File, exit;

import 'package:app/controller/home.controller.dart';
import 'package:app/page/dbSetup/db_setting.dart';
import 'package:app/page/setting/QueryReceivedEvent.dart';
import 'package:app/page/setting/RelaySetting.dart';
import 'package:app/page/setting/UnreadMessages.dart';
import 'package:app/page/setting/UploadedPubkeys.dart';
import 'package:app/page/setting/file_storage_server.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:settings_ui/settings_ui.dart';

import '../../service/storage.dart';
import '../components.dart';
import 'NostrEvents/NostrEvents_bindings.dart';
import 'NostrEvents/NostrEvents_page.dart';

class MoreChatSetting extends StatelessWidget {
  const MoreChatSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Chat Settings'),
        ),
        body: SettingsList(
          platform: DevicePlatform.iOS,
          sections: [
            SettingsSection(tiles: [
              SettingsTile.navigation(
                  leading: const Icon(CupertinoIcons.globe),
                  onPressed: (c) {
                    Get.to(() => const RelaySetting());
                  },
                  title: const Text('Relay Server')),
              SettingsTile.navigation(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text("Media Server"),
                onPressed: (context) {
                  Get.to(() => const FileStorageSetting());
                },
              ),
              SettingsTile.navigation(
                  leading: const Icon(Icons.notifications_outlined),
                  onPressed: (x) {
                    handleNotificationSettting();
                  },
                  title: const Text('Notifications'))
            ]),
            SettingsSection(title: const Text('Backup'), tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.dataset_outlined),
                title: const Text("Database Setting"),
                onPressed: handleDBSettting,
              )
            ]),
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
            ]),
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
    await Get.find<WebsocketService>().start();
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
                    if (res) {
                      closeAllRelays();
                      return;
                    }
                    restartAllRelays();
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

  enableImportDB(BuildContext context) {
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

  handleNotificationSettting() async {
    HomeController homeController = Get.find<HomeController>();
    bool permission = await NotifyService.hasNotifyPermission();
    show300hSheetWidget(
        Get.context!,
        'Notifications',
        Obx(
          () => SettingsList(platform: DevicePlatform.iOS, sections: [
            SettingsSection(title: const Text('Notification setting'), tiles: [
              SettingsTile.switchTile(
                  initialValue:
                      homeController.notificationStatus.value && permission,
                  description: NoticeTextWidget.warning(
                      'When the notification function is turned on, receiving addresses will be uploaded to the notification server.'),
                  onToggle: (res) async {
                    res ? enableNotification() : disableNotification();
                  },
                  title: const Text('Notification status')),
              if (homeController.debugModel.value || kDebugMode)
                SettingsTile.navigation(
                  title: const Text("FCMToken"),
                  onPressed: (context) {
                    Clipboard.setData(
                        ClipboardData(text: NotifyService.fcmToken ?? ''));
                    EasyLoading.showSuccess('Copied');
                  },
                  value: Text(
                      '${(NotifyService.fcmToken ?? '').substring(0, NotifyService.fcmToken != null ? 5 : 0)}...',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                ),
              SettingsTile.navigation(
                  title: const Text('Open System Settings'),
                  onPressed: (context) async {
                    await AppSettings.openAppSettings();
                  }),
              SettingsTile.navigation(
                  title: const Text('Listening Pubkey Stats'),
                  onPressed: (context) async {
                    Get.to(() => const UploadedPubkeys());
                  }),
            ])
          ]),
        ));
  }

  disableNotification() {
    Get.dialog(CupertinoAlertDialog(
      title: const Text("Alert"),
      content: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 15),
          child: const Text(
              'Once deactivated, your receiving addresses will be automatically deleted from the notification server.')),
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
            EasyLoading.show(status: 'Processing');
            try {
              await NotifyService.updateUserSetting(false);
              EasyLoading.showSuccess('Disabled');
            } catch (e, s) {
              logger.e(e.toString(), error: e, stackTrace: s);
              EasyLoading.showError(e.toString());
            }
            Get.back();
          },
        ),
      ],
    ));
  }

  enableNotification() {
    Get.dialog(CupertinoAlertDialog(
      title: const Text("Alert"),
      content: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 15),
          child: const Text(
              'Once activated, your receiving addresses will be automatically uploaded to the notification server.')),
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
            EasyLoading.show(status: 'Processing');
            var setting =
                await FirebaseMessaging.instance.getNotificationSettings();

            if (setting.authorizationStatus == AuthorizationStatus.denied) {
              EasyLoading.showSuccess(
                  "Please enable this config in system setting");

              await AppSettings.openAppSettings();
              return;
            }
            try {
              if (setting.authorizationStatus ==
                      AuthorizationStatus.notDetermined ||
                  NotifyService.fcmToken == null) {
                await NotifyService.requestPremissionAndInit();
              }

              await NotifyService.updateUserSetting(true);
              EasyLoading.showSuccess('Enabled');
            } catch (e, s) {
              logger.e(e.toString(), error: e, stackTrace: s);
              EasyLoading.showError(e.toString());
            }
            Get.back();
          },
        ),
      ],
    ));
  }
}
