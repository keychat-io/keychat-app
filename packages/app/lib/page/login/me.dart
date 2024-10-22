import 'package:app/nostr-core/relay_websocket.dart';
import 'package:app/page/login/CreateAccount.dart';
import 'package:app/page/login/OnboardingPage2.dart';
import 'package:app/page/setting/file_storage_server.dart';
import 'package:app/page/setting/UploadedPubkeys.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/page/components.dart';
import 'package:app/page/setting/relay_info/relay_info_bindings.dart';
import 'package:app/page/setting/relay_info/relay_info_page.dart';
import 'package:app/utils.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:app/models/models.dart';

import '../../controller/setting.controller.dart';
import '../../service/relay.service.dart';
import '../routes.dart';

class MinePage extends GetView<SettingController> {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    WebsocketService ws = Get.find<WebsocketService>();
    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: GestureDetector(
            child: const Text('Me'),
            onTap: () {
              Get.find<HomeController>().troggleDebugModel();
            },
          )),
      // ignore: avoid_unnecessary_containers
      body: Container(
          padding: const EdgeInsets.only(bottom: kMinInteractiveDimension),
          child: Obx(() => SettingsList(
                platform: DevicePlatform.iOS,
                sections: [
                  SettingsSection(
                      margin: const EdgeInsetsDirectional.only(
                          start: 16, end: 16, bottom: 16, top: 0),
                      title: const Text('Chat ID List'),
                      tiles: [
                        ...getIDList(
                            context,
                            Get.find<HomeController>()
                                .identities
                                .values
                                .toList()),
                        SettingsTile(
                            title: const Text("Create / Import ID"),
                            trailing: Icon(CupertinoIcons.add,
                                color: Theme.of(Get.context!)
                                    .iconTheme
                                    .color
                                    ?.withOpacity(0.5),
                                size: 22),
                            onPressed: (context) async {
                              List<Identity> identities =
                                  Get.find<HomeController>()
                                      .identities
                                      .values
                                      .toList();
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
                  cashuSetting(context),
                  SettingsSection(
                    margin: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16, vertical: 16),
                    title: const Text("Message Relay List"),
                    tiles: [
                      ...ws.channels.values.map((RelayWebsocket rw) =>
                          SettingsTile.navigation(
                            title: Text(rw.relay.url),
                            leading: Icon(
                                rw.relay.isDefault ? Icons.star : Icons.circle,
                                size: rw.relay.isDefault ? 16 : 12,
                                color: getColorByStatus(rw.channelStatus)),
                            value: rw.relay.active
                                ? (ws.relayMessageFeeModels[rw.relay.url] !=
                                        null
                                    ? ws.relayMessageFeeModels[rw.relay.url]!
                                                .amount ==
                                            0
                                        ? const Text('free')
                                        : Text(
                                            '${ws.relayMessageFeeModels[rw.relay.url]!.amount} ${ws.relayMessageFeeModels[rw.relay.url]!.unit.name}')
                                    : const Text('free'))
                                : null,
                            onPressed: (context) {
                              Get.to(() => const RelayInfoPage(),
                                  arguments: rw.relay,
                                  binding: RelayInfoBindings());
                            },
                          )),
                      SettingsTile(
                        title: const Text('Add'),
                        onPressed: _showAddRelayDialog,
                        trailing: Icon(
                          CupertinoIcons.add,
                          color: Theme.of(Get.context!)
                              .iconTheme
                              .color
                              ?.withOpacity(0.5),
                          size: 22,
                        ),
                      )
                    ],
                  ),
                  // SettingsSection(
                  //     margin: const EdgeInsetsDirectional.symmetric(
                  //         horizontal: 16, vertical: 16),
                  //     tiles: [
                  //       SettingsTile.navigation(
                  //         leading: SvgPicture.asset('assets/images/webrtc.svg',
                  //             height: 20,
                  //             width: 20,
                  //             colorFilter: const ColorFilter.mode(
                  //                 Colors.grey, BlendMode.srcIn)),
                  //         title: const Text("WebRTC ICE"),
                  //         onPressed: (context) {
                  //           Get.toNamed(Routes.webrtcSetting);
                  //         },
                  //       ),
                  //     ]),
                  SettingsSection(
                    margin: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16, vertical: 16),
                    tiles: [
                      // SettingsTile.navigation(
                      //     leading: const Icon(Icons.notifications_outlined),
                      //     onPressed: (c) {
                      //       Get.toNamed(Routes.login);
                      //     },
                      //     title: const Text('login')),

                      SettingsTile.navigation(
                          leading: const Icon(Icons.notifications_outlined),
                          onPressed: handleNotificationSettting,
                          title: const Text('Notifications')),
                      SettingsTile.navigation(
                        leading: const Icon(Icons.folder_open_outlined),
                        title: const Text("File Storage Server"),
                        onPressed: (context) {
                          Get.to(() => const FileStorageSetting());
                        },
                      ),
                      SettingsTile.navigation(
                        leading: const Icon(CupertinoIcons.settings),
                        title: const Text("More Settings"),
                        onPressed: (context) async {
                          PackageInfo packageInfo =
                              await PackageInfo.fromPlatform();
                          controller.appVersion.value =
                              "${packageInfo.version}+${packageInfo.buildNumber}";
                          Get.toNamed(Routes.settingMore);
                        },
                      ),
                      SettingsTile.navigation(
                        leading: const Icon(CupertinoIcons.question_circle),
                        title: const Text("About Keychat"),
                        onPressed: (context) {
                          Get.to(() => const OnboardingPage2());
                        },
                      ),
                    ],
                  ),
                ],
              ))),
    );
  }

  void _showAddRelayDialog(BuildContext context) {
    SettingController settingController = Get.find<SettingController>();
    Get.dialog(CupertinoAlertDialog(
      title: const Text("Add Nostr Relay"),
      content: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(top: 15),
        child: TextField(
          controller: settingController.relayTextController,
          textInputAction: TextInputAction.done,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Server url',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text("Cancel"),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () async {
            Get.back();
            var url = settingController.relayTextController.text.trim();
            if (url.startsWith("ws://") || url.startsWith("wss://")) {
              await RelayService().addAndConnect(url);
              settingController.relayTextController.clear();
              return;
            } else {
              EasyLoading.showError("Please input right format relay");
              settingController.relayTextController.clear();
            }
          },
          child: const Text("Confirm"),
        ),
      ],
    ));
  }

  SettingsSection cashuSetting(BuildContext buildContext) {
    EcashController? ec = getGetxController<EcashController>();

    return SettingsSection(
        margin:
            const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 16),
        tiles: [
          SettingsTile.navigation(
            leading: const Icon(
              CupertinoIcons.bitcoin,
              color: Color(0xfff2a900),
            ),
            value: Text(
                '${ec?.totalSats.value.toString() ?? '-'} ${EcashTokenSymbol.sat.name}'),
            onPressed: (context) async {
              Get.toNamed(Routes.ecash);
            },
            title: const Text("Bitcoin Ecash"),
          ),
        ]);
  }

  handleNotificationSettting(BuildContext context) async {
    HomeController hc = Get.find<HomeController>();
    bool permission = await NotifyService.hasNotifyPermission();
    show300hSheetWidget(
        Get.context!,
        'Notifications',
        Obx(
          () => SettingsList(platform: DevicePlatform.iOS, sections: [
            SettingsSection(title: const Text('Notification setting'), tiles: [
              SettingsTile.switchTile(
                  initialValue: hc.notificationStatus.value && permission,
                  description: NoticeTextWidget.warning(
                      'When the notification function is turned on, receiving addresses will be uploaded to the notification server.'),
                  onToggle: (res) async {
                    res ? enableNotification() : disableNotification();
                  },
                  title: const Text('Notification status')),
              if (hc.debugModel.value || kDebugMode)
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
              Get.back();
            } catch (e, s) {
              logger.e(e.toString(), error: e, stackTrace: s);
              EasyLoading.showError(e.toString());
            }
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
                await NotifyService.init(true);
              }

              await NotifyService.updateUserSetting(true);
              EasyLoading.showSuccess('Enabled');
              Get.back();
            } catch (e, s) {
              logger.e(e.toString(), error: e, stackTrace: s);
              EasyLoading.showError(e.toString());
            }
          },
        ),
      ],
    ));
  }

  getColorByStatus(RelayStatusEnum status) {
    switch (status) {
      case RelayStatusEnum.connecting:
        return Colors.yellow;
      case RelayStatusEnum.success:
        return Colors.green;
      case RelayStatusEnum.failed:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
