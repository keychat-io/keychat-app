import 'package:app/page/chat/SelectRoomRelay.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/contact.service.dart';
import 'package:flutter/cupertino.dart';
import 'package:app/service/chatx.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

import '../../controller/chat.controller.dart';
import '../../models/room.dart';
import '../../service/signal_chat.service.dart';
import '../components.dart';
import 'encrypt_mode_widget.dart.dart';

class ChatSettingsMoreDart extends StatelessWidget {
  final ChatController chatController;
  const ChatSettingsMoreDart({super.key, required this.chatController});

  @override
  Widget build(BuildContext context) {
    List<String> receiveKeys =
        ContactService().getMyReceiveKeys(chatController.roomObs.value) ?? [];
    return Scaffold(
        appBar:
            AppBar(centerTitle: true, title: const Text('Security Settings')),
        body: Obx(() => SettingsList(platform: DevicePlatform.iOS, sections: [
              SettingsSection(
                  title: const Text('Message Encrypt Protocol'),
                  tiles: [
                    SettingsTile.navigation(
                      title: const Text('Encrypt mode'),
                      leading: const Icon(CupertinoIcons.lock),
                      value: chatController.roomObs.value.encryptMode ==
                              EncryptMode.signal
                          ? textP('Signal procotol', Colors.green)
                          : textP('Nostr nip04', Colors.red),
                      onPressed: (context) async {
                        // it is my self
                        if (chatController.roomObs.value.toMainPubkey ==
                            chatController.roomObs.value
                                .getIdentity()
                                .curve25519PkHex) {
                          EasyLoading.showError(
                              'You can only use nip04 mode to talk to yourself');
                          return;
                        }
                        showFitSheetWidget(context, 'Encrypt Mode', [
                          EncryptModeWidget(chatController: chatController)
                        ]);
                      },
                    ),
                    if (chatController.roomObs.value.encryptMode ==
                        EncryptMode.signal)
                      SettingsTile.navigation(
                        title: const Text('Reset session status'),
                        leading: const Icon(CupertinoIcons.refresh),
                        description: const Text(
                            'Execute this action when you can\'t receive new messages from your friend'),
                        onPressed: (value) async {
                          Get.dialog(CupertinoAlertDialog(
                            title: const Text('Request sent successfully'),
                            content: const Text(
                                'Waiting for your friend comes online'),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('OK'),
                                onPressed: () async {
                                  await Get.find<ChatxService>()
                                      .deleteSignalSessionKPA(chatController
                                          .room); // delete old session
                                  await SignalChatService().sendHelloMessage(
                                      chatController.room,
                                      chatController.room.getIdentity(),
                                      greeting: 'Reset signal session status');
                                  EasyLoading.showInfo(
                                      'Request sent successfully.');
                                  Get.back();
                                },
                              )
                            ],
                          ));
                        },
                      )
                  ]),
              SettingsSection(title: const Text('Message Relays'), tiles: [
                SettingsTile(
                  title: const Text('SendTo'),
                  leading: const Icon(CupertinoIcons.up_arrow),
                  value: Obx(() => Flexible(
                      child: Text(chatController
                              .roomObs.value.sendingRelays.isNotEmpty
                          ? chatController.roomObs.value.sendingRelays.join(',')
                          : ''))),
                  onPressed: (c) {
                    if (chatController.roomObs.value.sendingRelays.isEmpty) {
                      return;
                    }
                    Get.dialog(CupertinoAlertDialog(
                      title: const Text('Delete Config'),
                      content:
                          const Text('Are you sure to delete receving config?'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Get.back();
                          },
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          onPressed: () async {
                            chatController.roomObs.value.receivingRelays = [];
                            await RoomService().updateRoomAndRefresh(
                                chatController.roomObs.value);
                            EasyLoading.showToast('Save Success');
                            Get.back();
                          },
                          child: const Text('Delete'),
                        )
                      ],
                    ));
                  },
                ),
                SettingsTile.navigation(
                  title: const Text('ReceiveFrom'),
                  leading: const Icon(CupertinoIcons.down_arrow),
                  description: Obx(() => Text(chatController
                          .roomObs.value.receivingRelays.isNotEmpty
                      ? chatController.roomObs.value.receivingRelays.join(',')
                      : '')),
                  onPressed: (context) async {
                    List<String>? relays = await Get.bottomSheet(
                        SelectRoomRelay(
                            chatController.roomObs.value.receivingRelays));
                    if (relays == null) return;
                    chatController.roomObs.value.receivingRelays = relays;
                    await RoomService()
                        .updateRoomAndRefresh(chatController.roomObs.value);
                    await SignalChatService().sendRelaySyncMessage(
                        chatController.roomObs.value, relays);
                    EasyLoading.showToast('Save Success');
                  },
                ),
              ]),
              if (receiveKeys.isNotEmpty)
                SettingsSection(
                    title: const Text('My Receiving Addresses'),
                    tiles: receiveKeys
                        .map((e) => SettingsTile(title: Text(e)))
                        .toList())
            ])));
  }
}
