import 'dart:io' show exit;

import 'package:app/controller/setting.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/page/components.dart';
import 'package:app/page/dbSetup/db_setting.dart';

import 'package:app/controller/home.controller.dart';
import 'package:app/page/FileExplore.dart';
import 'package:app/page/login/OnboardingPage2.dart';
import 'package:app/page/routes.dart';
import 'package:app/page/setting/BiometricAuthScreen.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
import 'package:app/service/file.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class AppGeneralSetting extends StatefulWidget {
  const AppGeneralSetting({super.key});

  @override
  State<AppGeneralSetting> createState() => _AppGeneralSettingState();
}

class _AppGeneralSettingState extends State<AppGeneralSetting> {
  late SettingController controller;
  bool _biometricsEnabled = false;
  late String startupTabName;
  HomeController hc = Get.find<HomeController>();

  @override
  void initState() {
    super.initState();
    controller = Get.find<SettingController>();
    setStartupTabName();
    _biometricsEnabled = controller.biometricsEnabled.value;
  }

  void setStartupTabName() {
    setState(() {
      startupTabName = hc.defaultTabConfig.entries
          .firstWhere((entry) => entry.value == hc.defaultSelectedTab.value)
          .key as String;
    });
  }

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
                        clipBehavior: Clip.antiAlias,
                        shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(4))),
                        Obx(() => SettingsList(
                                platform: DevicePlatform.iOS,
                                sections: [
                                  SettingsSection(
                                      title: const Text('Select theme mode'),
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
                                          title: const Text('System Mode'),
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
                                          title: const Text('Light Mode'),
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
                                            Get.changeThemeMode(ThemeMode.dark);
                                            controller.themeMode.value =
                                                ThemeMode.dark.name;
                                            await Storage.setString(
                                                StorageKeyString.themeMode,
                                                ThemeMode.dark.name);
                                          },
                                          title: const Text('Dark Mode'),
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
                                ])));
                  },
                  title: const Text('Dark Mode')),
              SettingsTile.navigation(
                leading: const Icon(CupertinoIcons.home),
                title: const Text('Startup Tab'),
                value: Text(startupTabName),
                onPressed: (context) async {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return RadioGroup<int>(
                            groupValue: hc.defaultSelectedTab.value,
                            onChanged: (value) {
                              if (value == null) return;
                              hc.setDefaultSelectedTab(value);
                              EasyLoading.showSuccess('Set successfully');
                              setStartupTabName();
                              Get.back<void>();
                            },
                            child: SimpleDialog(
                                title: const Text('Select startup tab'),
                                children: hc.defaultTabConfig.entries
                                    .map((entry) => ListTile(
                                          leading:
                                              Radio<int>(value: entry.value),
                                          title: Text(entry.key),
                                        ))
                                    .toList()));
                      });
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(CupertinoIcons.doc),
                title: const Text('App File Explore'),
                onPressed: (context) async {
                  Get.to(() => FileExplorerPage(dir: controller.appFolder),
                      id: GetPlatform.isDesktop ? GetXNestKey.setting : null);
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(CupertinoIcons.question_circle),
                title: const Text('About Keychat'),
                onPressed: (context) {
                  Get.to(() => const OnboardingPage2(),
                      id: GetPlatform.isDesktop ? GetXNestKey.setting : null);
                },
              ),
            ]),
            if (GetPlatform.isMobile)
              SettingsSection(title: const Text('Security'), tiles: [
                SettingsTile.switchTile(
                    initialValue: _biometricsEnabled,
                    onToggle: (value) async {
                      await controller.setBiometricsStatus(value);
                      setState(() {
                        _biometricsEnabled = value;
                      });
                    },
                    leading: const Icon(Icons.security),
                    title: const Text('Use Device Authentication')),
                SettingsTile.navigation(
                    leading: const Icon(CupertinoIcons.clock),
                    title: const Text('Require authentication'),
                    value: Obx(() => Text(
                        formatAuthTime(controller.biometricsAuthTime.value))),
                    onPressed: (_) {
                      final authTimes = <int>[0, 1, 5, 15, 30, 60, 240, 480];
                      showModalBottomSheetWidget(
                          context,
                          'Require authentication',
                          Obx(() => SettingsList(
                                  platform: DevicePlatform.iOS,
                                  physics: const NeverScrollableScrollPhysics(),
                                  sections: [
                                    SettingsSection(
                                        tiles: authTimes
                                            .map(
                                              (int minutes) => SettingsTile(
                                                  onPressed: (context) {
                                                    controller
                                                        .setBiometricsAuthTime(
                                                            minutes);
                                                  },
                                                  title: Text(
                                                      formatAuthTime(minutes)),
                                                  trailing: controller
                                                              .biometricsAuthTime
                                                              .value ==
                                                          minutes
                                                      ? const Icon(
                                                          Icons.done,
                                                          color: Colors.green,
                                                        )
                                                      : null),
                                            )
                                            .toList())
                                  ])));
                    })
                // SettingsTile.navigation(
                //   leading: const Icon(Icons.pin),
                //   title: const Text("Reset PIN"),
                //   onPressed: (context) {
                //     Get.to(() => const ResetPinPage(),
                //         id: GetPlatform.isDesktop ? GetXNestKey.setting : null);
                //   },
                // ),
              ]),
            SettingsSection(title: const Text('Data Backup'), tiles: [
              SettingsTile.navigation(
                  leading: const Icon(Icons.storage),
                  title: const Text('Database Setting'),
                  onPressed: handleDBSettting)
            ]),
            SettingsSection(tiles: [
              SettingsTile.navigation(
                  leading: const Icon(
                    CupertinoIcons.trash,
                    color: Colors.red,
                  ),
                  title:
                      const Text('Logout', style: TextStyle(color: Colors.red)),
                  onPressed: deleteAccount)
            ])
          ],
        ));
  }

  String formatAuthTime(int minutes) {
    if (minutes == 0) return 'Immediately';
    if (minutes < 60) {
      if (minutes == 1) {
        return '$minutes minute';
      }
      return '$minutes minutes';
    }

    final hours = minutes ~/ 60;
    if (hours == 1) return '$hours hour';
    return '$hours hours';
  }

  Future<void> handleDBSettting(BuildContext context) async {
    final hc = Get.find<HomeController>();
    Get.bottomSheet(
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
        Obx(
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
                        title: const Text('Stop chat?'),
                        content: const Text(
                            'You will not be able to receive and send messages while the chat is stopped.'),
                        actions: <Widget>[
                          CupertinoDialogAction(
                            onPressed: Get.back,
                            child: const Text('Cancel'),
                          ),
                          CupertinoDialogAction(
                              isDestructiveAction: true,
                              child: const Text('Stop'),
                              onPressed: () async {
                                closeAllRelays();
                                Get.back<void>();
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
        ));
  }

  void _showSetEncryptionPwdDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    Get.dialog(
      CupertinoAlertDialog(
        title: const Text('Set encryption password'),
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
            onPressed: Get.back,
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
              Get.back<void>();
              await Future.delayed(const Duration(microseconds: 100));
              EasyLoading.show(status: 'Exporting...');
              try {
                await DbSetting().exportDB(confirmPasswordController.text);
                EasyLoading.showSuccess('Export successful');
              } catch (e, s) {
                logger.e(e.toString(), error: e, stackTrace: s);
                EasyLoading.showError('Export failed: $e');
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

  Future<void> closeAllRelays() async {
    final hc = Get.find<HomeController>();
    await Get.find<WebsocketService>().stopListening();
    hc.checkRunStatus.value = false;
  }

  Future deleteAccount(BuildContext context) {
    return Get.dialog(CupertinoAlertDialog(
      title: const Text('Logout All Identity?'),
      content: const Text('''
All app data will be deleted after logging out, so please make sure you have backed it up. 

Please make sure you have backed up your seed phrase and contacts. This cannot be undone.''',
          style: TextStyle(color: Colors.red)),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: Get.back,
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Logout'),
            onPressed: () async {
              // Biometrics Auth
              if (GetPlatform.isMobile) {
                final isBiometricsEnable =
                    await SecureStorage.instance.isBiometricsEnable();
                if (isBiometricsEnable) {
                  final authed = await Get.to(
                      () => const BiometricAuthScreen(
                          canPop: true, title: 'Authenticate to Logout'),
                      fullscreenDialog: true,
                      popGesture: true,
                      transition: Transition.fadeIn);
                  if (authed == null || authed == false) {
                    return;
                  }
                }
              }
              EasyLoading.show(status: 'Processing...');
              try {
                DBProvider.instance.deleteAll();
                await FileService.instance
                    .deleteAllFolder(); // delete all files
                await Get.find<WebsocketService>().stopListening();
                await Storage.clearAll();
                await SecureStorage.instance.clearAll();
                Storage.setInt(StorageKeyString.onboarding, 0);
                try {
                  await FirebaseMessaging.instance.deleteToken();
                  // ignore: empty_catches
                } catch (e) {}
                NotifyService.clearAll();
                if (kReleaseMode) {
                  EasyLoading.showSuccess('Logout successfully, App will exit');
                  await Future.delayed(const Duration(seconds: 2));
                  exit(0);
                }
                // for debug mode, just go to login page
                EasyLoading.showSuccess('Logout successfully');
                Get.offAllNamed(Routes.login);
              } catch (e, s) {
                final msg = Utils.getErrorMessage(e);
                logger.e(msg, error: e, stackTrace: s);
                EasyLoading.showError(msg,
                    duration: const Duration(seconds: 4));
              }
            }),
      ],
    ));
  }
}
