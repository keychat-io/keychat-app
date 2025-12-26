import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import 'package:keychat/page/setting/notification_setting_page.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:settings_ui/settings_ui.dart';

class MoreChatSetting extends GetView<HomeController> {
  const MoreChatSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final ws = Get.find<WebsocketService>();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Chat Settings'),
      ),
      body: Obx(
        () => SettingsList(
          platform: DevicePlatform.iOS,
          sections: [
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  leading: const Icon(CupertinoIcons.globe),
                  value: ws.relayConnectedCount.value == 0
                      ? const Text('Connecting')
                      : Text(
                          ws.relayConnectedCount.value.toString(),
                        ),
                  onPressed: (c) async {
                    await Get.to(
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
                    GetPlatform.isMacOS ||
                    GetPlatform.isLinux)
                  SettingsTile.navigation(
                    leading: const Icon(Icons.notifications_outlined),
                    onPressed: (x) {
                      Get.to(
                        () => const NotificationSettingPage(),
                        id: GetPlatform.isDesktop ? GetXNestKey.setting : null,
                      );
                    },
                    title: const Text('Notifications'),
                  ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile.switchTile(
                  leading: const Icon(Icons.message),
                  title: const Text('Direct Messages'),
                  description: const Text(
                    'Receiving DMs from other Nostr apps, encrypted by nostr Nip04 and Nip17',
                  ),
                  onPressed: (context) async {},
                  initialValue: controller.enableDMFromNostrApp.value,
                  onToggle: (bool value) async {
                    await Storage.setBool(
                      StorageKeyString.enableDMFromNostrApp,
                      value,
                    );
                    controller.enableDMFromNostrApp.value = value;
                    final tips = value
                        ? 'Enabled. Your will receive DMs from other Nostr apps.'
                        : 'Disabled. You will not receive DMs from other Nostr apps.';
                    await EasyLoading.showSuccess(tips);
                  },
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
                      EasyLoading.showError(
                        'Failed to upload KeyPackages: $msg',
                      );
                    }
                  },
                ),
              ],
            ),
            if (controller.debugModel.value)
              SettingsSection(
                title: const Text('Flatpak debug Zone'),
                tiles: [
                  SettingsTile.navigation(
                    leading: const Icon(Icons.event),
                    title: const Text('Flatpak ENV'),
                    value: Text(Utils.isRunningInFlatpak() ? 'Yes' : 'No'),
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
      ),
    );
  }
}
