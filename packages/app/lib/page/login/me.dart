import 'package:app/page/browser/BrowserSetting.dart';
import 'package:app/page/login/CreateAccount.dart';
import 'package:app/page/setting/RelaySetting.dart';
import 'package:app/page/setting/app_general_setting.dart';
import 'package:app/page/setting/file_storage_server.dart';
import 'package:app/page/setting/UploadedPubkeys.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/service/notify.service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/page/components.dart';

import 'package:app/utils.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:app/models/models.dart';

import '../../controller/setting.controller.dart';
import '../routes.dart';

class MinePage extends GetView<SettingController> {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    HomeController homeController = Get.find<HomeController>();
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: GestureDetector(
            child: const Text('Me'),
            onTap: () {
              homeController.troggleDebugModel();
            },
          ),
        ),
        body: Container(
          padding:
              const EdgeInsets.only(bottom: kMinInteractiveDimension * 1.5),
          child: Obx(() => SettingsList(
                platform: DevicePlatform.iOS,
                sections: [
                  SettingsSection(
                      margin: const EdgeInsetsDirectional.only(
                          start: 16, end: 16, bottom: 16, top: 0),
                      title: const Text('Chat / Browser ID'),
                      tiles: [
                        ...getIDList(context,
                            homeController.allIdentities.values.toList()),
                        SettingsTile(
                            title: const Text("Create / Import ID"),
                            trailing: Icon(CupertinoIcons.add,
                                color: Theme.of(Get.context!)
                                    .iconTheme
                                    .color
                                    ?.withValues(alpha: 0.5),
                                size: 22),
                            onPressed: (context) async {
                              List<Identity> identities =
                                  homeController.allIdentities.values.toList();
                              List<String> npubs =
                                  identities.map((e) => e.npub).toList();
                              String? mnemonic =
                                  await SecureStorage.instance.getPhraseWords();
                              Get.to(
                                  () => CreateAccount(
                                      type: "me",
                                      mnemonic: mnemonic,
                                      npubs: npubs),
                                  arguments: 'create');
                            })
                      ]),
                  SettingsSection(
                      margin: const EdgeInsetsDirectional.symmetric(
                          horizontal: 16, vertical: 16),
                      tiles: [
                        SettingsTile.navigation(
                          leading: const Icon(
                            CupertinoIcons.bitcoin,
                            color: Color(0xfff2a900),
                          ),
                          value: Text(
                              '${getGetxController<EcashController>()?.totalSats.value.toString() ?? '-'} ${EcashTokenSymbol.sat.name}'),
                          onPressed: (context) async {
                            Get.toNamed(Routes.ecash);
                          },
                          title: const Text("Bitcoin Ecash"),
                        ),
                      ]),
                  SettingsSection(
                      title: const Text('Chat Settings'),
                      margin: const EdgeInsetsDirectional.symmetric(
                          horizontal: 16, vertical: 16),
                      tiles: [
                        SettingsTile.navigation(
                            leading: const Icon(CupertinoIcons.globe),
                            onPressed: (c) {
                              Get.to(() => const RelaySetting());
                            },
                            title: const Text('Relay Server')),
                        SettingsTile.navigation(
                          leading: const Icon(Icons.folder_open_outlined),
                          title: const Text("File Storage Server"),
                          onPressed: (context) {
                            Get.to(() => const FileStorageSetting());
                          },
                        ),
                        SettingsTile.navigation(
                            leading: const Icon(Icons.notifications_outlined),
                            onPressed: (x) {
                              handleNotificationSettting(homeController);
                            },
                            title: const Text('Notifications')),
                        SettingsTile.navigation(
                          leading: const Icon(CupertinoIcons.chat_bubble),
                          title: const Text("More Chat Settings"),
                          onPressed: (context) async {
                            Get.toNamed(Routes.settingMore);
                          },
                        ),
                      ]),
                  SettingsSection(
                    margin: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16, vertical: 16),
                    tiles: [
                      SettingsTile.navigation(
                          title: const Text("Browser Settings"),
                          leading: const Icon(CupertinoIcons.compass),
                          onPressed: (context) async {
                            Get.to(() => const BrowserSetting());
                          }),
                    ],
                  ),
                  SettingsSection(
                    margin: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16, vertical: 16),
                    tiles: [
                      SettingsTile.navigation(
                        leading: const Icon(CupertinoIcons.settings),
                        title: const Text("General Settings"),
                        onPressed: (context) {
                          Get.to(() => const AppGeneralSetting());
                        },
                      ),
                      SettingsTile(
                        leading: const Icon(Icons.verified_outlined),
                        title: const Text("App Version"),
                        value: textP(controller.appVersion.value),
                        onPressed: (context) {},
                      ),
                    ],
                  ),
                ],
              )),
        ));
  }

  handleNotificationSettting(HomeController homeController) async {
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

  List<SettingsTile> getIDList(BuildContext context, List identities) {
    List<SettingsTile> res = [];
    for (var i = 0; i < identities.length; i++) {
      Identity identity = identities[i];

      res.add(SettingsTile.navigation(
          leading:
              getRandomAvatar(identity.secp256k1PKHex, height: 30, width: 30),
          title: Text(
            identity.displayName.length > 8
                ? "${identity.displayName.substring(0, 8)}..."
                : identity.displayName,
            style: i == 0
                ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary)
                : Theme.of(context).textTheme.bodyLarge,
          ),
          value: Text(getPublicKeyDisplay(identity.npub)),
          onPressed: (context) async {
            Get.toNamed(Routes.settingMe, arguments: identity);
          }));
    }
    return res;
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
