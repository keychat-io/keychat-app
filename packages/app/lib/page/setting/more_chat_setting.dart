import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/page/setting/MediaRelaySettings.dart';
import 'package:keychat/page/setting/NostrEvents/NostrEvents_bindings.dart';
import 'package:keychat/page/setting/NostrEvents/NostrEvents_page.dart';
import 'package:keychat/page/setting/QueryReceivedEvent.dart';
import 'package:keychat/page/setting/RelaySetting.dart';
import 'package:keychat/page/setting/UnreadMessages.dart';
import 'package:keychat/page/setting/UploadedPubkeys.dart';
import 'package:keychat/page/widgets/notice_text_widget.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:permission_master/permission_master.dart';
import 'package:settings_ui/settings_ui.dart';

class MoreChatSetting extends StatelessWidget {
  const MoreChatSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final ws = Get.find<WebsocketService>();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Chat Settings'),
      ),
      body: SettingsList(
        platform: DevicePlatform.iOS,
        sections: [
          SettingsSection(
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(CupertinoIcons.globe),
                value: Obx(
                  () => ws.relayConnectedCount.value == 0
                      ? const Text('Connecting')
                      : Text(ws.relayConnectedCount.value.toString()),
                ),
                onPressed: (c) {
                  Get.to(
                    () => const RelaySetting(),
                    id: GetPlatform.isDesktop ? GetXNestKey.setting : null,
                  );
                },
                title: const Text('Message Relay'),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Media Relay'),
                onPressed: (context) {
                  Get.to(
                    () => const MediaRelaySettings(),
                    id: GetPlatform.isDesktop ? GetXNestKey.setting : null,
                  );
                },
              ),
              if (GetPlatform.isIOS ||
                  GetPlatform.isAndroid ||
                  GetPlatform.isMacOS)
                SettingsTile.navigation(
                  leading: const Icon(Icons.notifications_outlined),
                  onPressed: (x) async {
                    await handleNotificationSetting();
                  },
                  title: const Text('Notifications'),
                ),
            ],
          ),
          SettingsSection(
            title: const Text('MLS Group Settings'),
            tiles: [
              SettingsTile(
                leading: const Icon(CupertinoIcons.cloud_upload),
                title: const Text('Upload KeyPackage'),
                onPressed: (context) async {
                  try {
                    final identities = Get.find<HomeController>()
                        .allIdentities
                        .values
                        .toList();
                    await MlsGroupService.instance.uploadKeyPackages(
                      forceUpload: true,
                      identities: identities,
                    );
                    EasyLoading.showSuccess('Upload Success');
                  } catch (e, s) {
                    final msg = Utils.getErrorMessage(e);
                    logger.e(
                      'Failed to upload KeyPackages: $msg',
                      stackTrace: s,
                    );
                    EasyLoading.showError('Failed to upload KeyPackages: $msg');
                  }
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Debug Zone'),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.event),
                title: const Text('Failed Events'),
                onPressed: (context) async {
                  Get.to(
                    () => const NostrEventsPage(),
                    binding: NostrEventsBindings(),
                    id: GetPlatform.isDesktop ? GetXNestKey.setting : null,
                  );
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.event),
                title: const Text('Query Received Event'),
                onPressed: (context) async {
                  Get.to(
                    () => const QueryReceivedEvent(),
                    id: GetPlatform.isDesktop ? GetXNestKey.setting : null,
                  );
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.copy),
                title: const Text('Unread Messages'),
                onPressed: (context) async {
                  Get.to(
                    () => const UnreadMessages(),
                    id: GetPlatform.isDesktop ? GetXNestKey.setting : null,
                  );
                },
              ),
            ],
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

  Future<void> handleNotificationSetting() async {
    final homeController = Get.find<HomeController>();
    final permission = await NotifyService.instance.isNotifyPermissionGrant();
    await Get.bottomSheet<void>(
      Obx(
        () => SettingsList(
          platform: DevicePlatform.iOS,
          sections: [
            SettingsSection(
              title: const Text('Notification setting'),
              tiles: [
                SettingsTile.switchTile(
                  initialValue:
                      homeController.notificationStatus.value && permission,
                  description: NoticeTextWidget.warning(
                    'When the notification function is turned on, receiving addresses will be uploaded to the notification server.',
                  ),
                  onToggle: (res) async {
                    final result = await (res
                        ? enableNotification()
                        : disableNotification());
                    if (result) {
                      // close bottomsheet
                      Get.back<void>();
                    }
                  },
                  title: const Text('Notification status'),
                ),
                SettingsTile.navigation(
                  title: const Text('FCMToken'),
                  onPressed: (context) {
                    if (NotifyService.instance.fcmToken == null) {
                      EasyLoading.showError(
                        'FCM Token not available! Please check your network and re-open the notification status.',
                      );
                      return;
                    }
                    Clipboard.setData(
                      ClipboardData(
                        text: NotifyService.instance.fcmToken ?? '',
                      ),
                    );
                    logger.i('FCMToken: ${NotifyService.instance.fcmToken}');
                    EasyLoading.showSuccess('Copied');
                  },
                  value: Text(
                    homeController.notificationStatus.value && permission
                        ? NotifyService.instance.fcmToken == null
                              ? 'Fetch Failed'
                              : NotifyService.instance.fcmToken!.substring(0, 5)
                        : '',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                SettingsTile.navigation(
                  title: const Text('Open System Settings'),
                  onPressed: (context) async {
                    await PermissionMaster().openAppSettings();
                  },
                ),
                SettingsTile.navigation(
                  title: const Text('Listening Pubkey Stats'),
                  onPressed: (context) async {
                    Get.to(() => const UploadedPubkeys());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> disableNotification() async {
    final res = await Get.dialog<bool>(
      CupertinoAlertDialog(
        title: const Text('Alert'),
        content: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 15),
          child: const Text(
            'Once deactivated, your receiving addresses will be automatically deleted from the notification server.',
          ),
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Get.back(result: true);
            },
          ),
          CupertinoDialogAction(
            child: const Text('Confirm'),
            onPressed: () async {
              EasyLoading.show(status: 'Processing');
              try {
                Get.find<HomeController>().notificationStatus.value = false;
                Get.find<HomeController>().notificationStatus.refresh();
                await Storage.setInt(
                  StorageKeyString.settingNotifyStatus,
                  NotifySettingStatus.disable,
                );
                await NotifyService.instance.clearAll();
                EasyLoading.showSuccess('Disable');
                Get.back(result: true);
              } catch (e, s) {
                logger.e(e.toString(), error: e, stackTrace: s);
                EasyLoading.showError(e.toString());
              }
            },
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<bool> enableNotification() async {
    final res = await Get.dialog<bool>(
      CupertinoAlertDialog(
        title: const Text('Alert'),
        content: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 15),
          child: const Text(
            'Once activated, your receiving addresses will be automatically uploaded to the notification server.',
          ),
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Get.back(result: false);
            },
          ),
          CupertinoDialogAction(
            child: const Text('Confirm'),
            onPressed: () async {
              try {
                EasyLoading.show(status: 'Initializing...');

                // Initialize notification service with permission request
                Get.find<HomeController>().notificationStatus.value = true;
                await Storage.setInt(
                  StorageKeyString.settingNotifyStatus,
                  NotifySettingStatus.enable,
                );
                await NotifyService.instance.init(requestPermission: true);

                // Check if initialization was successful
                final hasPermission = await NotifyService.instance
                    .isNotifyPermissionGrant();

                if (!hasPermission) {
                  await EasyLoading.showError(
                    'Please enable notification permission in system settings',
                  );
                  await PermissionMaster().openAppSettings();
                  Get.back(result: false);
                  return;
                }

                await NotifyService.instance.syncPubkeysToServer();
                await EasyLoading.showSuccess('Enabled');
                Get.back(result: true);
              } catch (e, s) {
                logger.e(e.toString(), error: e, stackTrace: s);
                await EasyLoading.showError(e.toString());
                Get.back(result: false);
              }
            },
          ),
        ],
      ),
    );
    return res ?? false;
  }
}
