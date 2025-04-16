// ignore_for_file: use_build_context_synchronously

import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/page/setting/QueryReceivedEvent.dart';
import 'package:app/page/setting/UnreadMessages.dart';
import 'package:app/page/setting/UploadedPubkeys.dart';
import 'package:app/page/setting/file_storage_server.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:settings_ui/settings_ui.dart';

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
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text("Media Server"),
                onPressed: (context) {
                  Get.to(() => const FileStorageSetting(),
                      id: GetPlatform.isDesktop ? GetXNestKey.setting : null);
                },
              ),
              if (GetPlatform.isIOS ||
                  GetPlatform.isAndroid ||
                  GetPlatform.isMacOS)
                SettingsTile.navigation(
                    leading: const Icon(Icons.notifications_outlined),
                    onPressed: (x) {
                      handleNotificationSettting();
                    },
                    title: const Text('Notifications'))
            ]),
            SettingsSection(title: const Text('MLS Group Settings'), tiles: [
              SettingsTile(
                  leading: const Icon(CupertinoIcons.cloud_upload),
                  title: const Text("Upload KeyPackage"),
                  onPressed: (context) async {
                    try {
                      await MlsGroupService.instance
                          .uploadKeyPackages(forceUpload: true);
                      EasyLoading.showSuccess('Upload Success');
                    } catch (e, s) {
                      String msg = Utils.getErrorMessage(e);
                      logger.e('Failed to upload KeyPackages: $msg',
                          stackTrace: s);
                      EasyLoading.showError(
                          'Failed to upload KeyPackages: $msg');
                    }
                  }),
            ]),
            SettingsSection(title: const Text('Debug Zone'), tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.event),
                title: const Text("Failed Events"),
                onPressed: (context) async {
                  Get.to(() => const NostrEventsPage(),
                      binding: NostrEventsBindings(),
                      id: GetPlatform.isDesktop ? GetXNestKey.setting : null);
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.event),
                title: const Text("Query Received Event"),
                onPressed: (context) async {
                  Get.to(() => const QueryReceivedEvent(),
                      id: GetPlatform.isDesktop ? GetXNestKey.setting : null);
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.copy),
                title: const Text("Unread Messages"),
                onPressed: (context) async {
                  Get.to(() => const UnreadMessages(),
                      id: GetPlatform.isDesktop ? GetXNestKey.setting : null);
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
                    bool? result = await (res
                        ? enableNotification()
                        : disableNotification());
                    if (result != null && result) {
                      // close bottomsheet
                      Get.back();
                    }
                  },
                  title: const Text('Notification status')),
              SettingsTile.navigation(
                title: const Text("FCMToken"),
                onPressed: (context) {
                  Clipboard.setData(
                      ClipboardData(text: NotifyService.fcmToken ?? ''));
                  logger.d('FCMToken: ${NotifyService.fcmToken}');
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
                    await AppSettings.openAppSettings(
                        type: AppSettingsType.notification);
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
    return Get.dialog(CupertinoAlertDialog(
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
            Get.back(result: true);
          },
        ),
        CupertinoDialogAction(
          child: const Text("Confirm"),
          onPressed: () async {
            EasyLoading.show(status: 'Processing');
            try {
              await NotifyService.updateUserSetting(false);
              EasyLoading.showSuccess('Disable');
              Get.back(result: true);
            } catch (e, s) {
              logger.e(e.toString(), error: e, stackTrace: s);
              EasyLoading.showError(e.toString());
            }
          },
        ),
      ],
    ));
  }

  Future<bool> enableNotification() async {
    return await Get.dialog(CupertinoAlertDialog(
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
            Get.back(result: true);
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

              await AppSettings.openAppSettings(
                  type: AppSettingsType.notification);
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
              Get.back(result: true);
            } catch (e, s) {
              logger.e(e.toString(), error: e, stackTrace: s);
              EasyLoading.showError(e.toString());
            }
          },
        ),
      ],
    ));
  }
}
