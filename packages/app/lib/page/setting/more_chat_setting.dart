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
import 'package:keychat/service/unifiedpush.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:permission_handler/permission_handler.dart';
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

  Future<void> closeAllRelays() async {
    final hc = Get.find<HomeController>();
    await Get.find<WebsocketService>().stopListening();
    hc.checkRunStatus.value = false;
  }

  Future<void> handleNotificationSetting() async {
    final homeController = Get.find<HomeController>();
    final permission = await NotifyService.instance.isNotifyPermissionGrant();

    // Get current push type (default to 'fcm')
    final pushType = RxString(
      Storage.getString(StorageKeyString.pushNotificationType) ?? 'fcm',
    );
    // Get current UnifiedPush distributor
    final currentDistributor = RxnString();
    if (GetPlatform.isAndroid || GetPlatform.isLinux) {
      currentDistributor.value = await UnifiedPushService.instance
          .getCurrentDistributor();
    }

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
                // Push type selection - only for Android and Linux
                if (GetPlatform.isAndroid || GetPlatform.isLinux)
                  SettingsTile.navigation(
                    leading: const Icon(Icons.swap_horiz),
                    title: const Text('Push Service'),
                    description: const Text(
                      'Choose between FCM (Google) or UnifiedPush (privacy-friendly)',
                    ),
                    value: Text(
                      pushType.value == 'fcm' ? 'FCM' : 'UnifiedPush',
                    ),
                    onPressed: (context) async {
                      await _showPushTypeSelector(pushType);
                    },
                  ),
                // UnifiedPush distributor selection - only when UnifiedPush is selected
                if ((GetPlatform.isAndroid || GetPlatform.isLinux) &&
                    pushType.value == 'unifiedpush')
                  SettingsTile.navigation(
                    leading: const Icon(Icons.apps),
                    title: const Text('UnifiedPush Distributor'),
                    description: const Text(
                      'Select the app that will handle push notifications',
                    ),
                    value: Text(
                      currentDistributor.value != null
                          ? _formatDistributorName(currentDistributor.value!)
                          : 'Not selected',
                    ),
                    onPressed: (context) async {
                      await _showDistributorSelector(currentDistributor);
                    },
                  ),
                // FCM Token - only show when FCM is selected
                if (pushType.value == 'fcm')
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
                                : NotifyService.instance.fcmToken!.substring(
                                    0,
                                    5,
                                  )
                          : '',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                // UnifiedPush Endpoint - only show when UnifiedPush is selected
                if ((GetPlatform.isAndroid || GetPlatform.isLinux) &&
                    pushType.value == 'unifiedpush')
                  SettingsTile.navigation(
                    title: const Text('Push Endpoint'),
                    onPressed: (context) {
                      final endpoint =
                          UnifiedPushService.instance.currentEndpoint;
                      if (endpoint == null) {
                        EasyLoading.showError(
                          'Push endpoint not available! Please select a distributor first.',
                        );
                        return;
                      }
                      Clipboard.setData(ClipboardData(text: endpoint));
                      logger.i('UnifiedPush Endpoint: $endpoint');
                      EasyLoading.showSuccess('Copied');
                    },
                    value: Text(
                      UnifiedPushService.instance.currentEndpoint != null
                          ? '${UnifiedPushService.instance.currentEndpoint!.substring(0, 20)}...'
                          : 'Not registered',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                SettingsTile.navigation(
                  title: const Text('Open System Settings'),
                  onPressed: (context) {
                    openAppSettings();
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

  /// Show push type selector dialog (FCM vs UnifiedPush)
  Future<void> _showPushTypeSelector(RxString pushType) async {
    final result = await showDialog<String>(
      context: Get.context!,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select Push Service'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('fcm'),
              child: ListTile(
                leading: Icon(
                  Icons.cloud,
                  color: pushType.value == 'fcm'
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: const Text('FCM (Firebase Cloud Messaging)'),
                subtitle: const Text('Google push service, requires GMS'),
                trailing: pushType.value == 'fcm'
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('unifiedpush'),
              child: ListTile(
                leading: Icon(
                  Icons.security,
                  color: pushType.value == 'unifiedpush'
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: const Text('UnifiedPush'),
                subtitle: const Text(
                  'Privacy-friendly, requires distributor app (e.g., ntfy)',
                ),
                trailing: pushType.value == 'unifiedpush'
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
          ],
        );
      },
    );

    if (result != null && result != pushType.value) {
      final oldPushType = pushType.value;

      await EasyLoading.show(status: 'Switching push service...');

      try {
        // Step 1: Clear old registration from server
        if (oldPushType == 'unifiedpush' &&
            UnifiedPushService.instance.isRegistered) {
          // Unregister from UnifiedPush (this also clears from server)
          await UnifiedPushService.instance.unregister();
        } else if (oldPushType == 'fcm' &&
            NotifyService.instance.fcmToken != null) {
          // Clear FCM registration from server
          await NotifyService.instance.clearAll();
        }

        // Step 2: Update storage with new push type
        pushType.value = result;
        await Storage.setString(StorageKeyString.pushNotificationType, result);

        // Step 3: Initialize new push service
        if (result == 'unifiedpush') {
          // Initialize UnifiedPush
          await UnifiedPushService.instance.init();
          await EasyLoading.showSuccess('Switched to UnifiedPush');
        } else {
          // Initialize FCM
          await NotifyService.instance.init();
          await EasyLoading.showSuccess('Switched to FCM');
        }
      } catch (e) {
        logger.e('Failed to switch push service', error: e);
        // Rollback on failure
        pushType.value = oldPushType;
        await Storage.setString(
          StorageKeyString.pushNotificationType,
          oldPushType,
        );
        await EasyLoading.showError('Failed to switch push service');
      }
    }
  }

  /// Show UnifiedPush distributor selector dialog
  Future<void> _showDistributorSelector(RxnString currentDistributor) async {
    await EasyLoading.show(status: 'Loading distributors...');

    final distributors = await UnifiedPushService.instance
        .getAvailableDistributors();
    await EasyLoading.dismiss();

    if (distributors.isEmpty) {
      await EasyLoading.showError(
        'No UnifiedPush distributors found.\nPlease install a distributor app like ntfy or NextPush.',
      );
      return;
    }

    final result = await showDialog<String>(
      context: Get.context!,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select Distributor'),
          children: distributors.map((distributor) {
            final isSelected = distributor == currentDistributor.value;
            final displayName = _formatDistributorName(distributor);
            return SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(distributor),
              child: ListTile(
                leading: Icon(
                  Icons.notifications_active,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(displayName),
                subtitle: Text(
                  distributor,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );

    if (result != null && result != currentDistributor.value) {
      await EasyLoading.show(status: 'Switching distributor...');
      try {
        // Unregister from current distributor if registered
        if (UnifiedPushService.instance.isRegistered) {
          await UnifiedPushService.instance.unregister();
        }

        // Save and register with new distributor
        await UnifiedPushService.instance.selectDistributor();

        currentDistributor.value = await UnifiedPushService.instance
            .getCurrentDistributor();
        await EasyLoading.showSuccess('Distributor changed');
      } catch (e) {
        logger.e('Failed to switch distributor', error: e);
        await EasyLoading.showError('Failed to switch distributor');
      }
    }
  }

  /// Format distributor package name to a more readable display name
  String _formatDistributorName(String packageName) {
    final knownDistributors = {
      'org.unifiedpush.distributor.fcm': 'FCM Distributor',
      'org.unifiedpush.distributor.nextpush': 'NextPush',
      'io.heckel.ntfy': 'ntfy',
      'org.unifiedpush.distributor.noprovider2push': 'NoProvider2Push',
      'im.vector.app': 'Element',
      'de.pixart.messenger': 'Pix-Art Messenger',
      'eu.siacs.conversations': 'Conversations',
    };

    if (knownDistributors.containsKey(packageName)) {
      return knownDistributors[packageName]!;
    }

    // Extract last part of package name and capitalize
    final parts = packageName.split('.');
    if (parts.isNotEmpty) {
      final name = parts.last;
      return name[0].toUpperCase() + name.substring(1);
    }
    return packageName;
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
                await EasyLoading.show(status: 'Initializing...');

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
                  await openAppSettings();
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
              } finally {
                await Future.delayed(const Duration(seconds: 2));
                await EasyLoading.dismiss();
              }
            },
          ),
        ],
      ),
    );
    return res ?? false;
  }
}
