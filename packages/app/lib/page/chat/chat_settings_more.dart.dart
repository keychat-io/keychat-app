import 'package:app/nostr-core/relay_websocket.dart';
import 'package:app/page/chat/SelectRoomRelay.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

import '../../controller/chat.controller.dart';
import '../../models/room.dart';
import '../../service/signalChat.service.dart';
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
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Security Settings'),
        ),
        body: Obx(() => SettingsList(platform: DevicePlatform.iOS, sections: [
              SettingsSection(title: const Text('Encrypt Protocl'), tiles: [
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
                    showFitSheetWidget(
                      context,
                      'Encrypt Mode',
                      [
                        EncryptModeWidget(
                          chatController: chatController,
                        )
                      ],
                    );
                  },
                ),
                if (chatController.roomObs.value.encryptMode ==
                    EncryptMode.signal)
                  SettingsTile.navigation(
                    title: const Text('Reset session status'),
                    leading: const Icon(CupertinoIcons.refresh),
                    description: const Text(
                        'Execute this action when you can\'t receive new messages from your friend. This will reset the session status of the chat room.'),
                    onPressed: (value) async {
                      Get.dialog(CupertinoAlertDialog(
                        title: const Text('Request sent successfully'),
                        content:
                            const Text('Waiting for your friend comes online'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('OK'),
                            onPressed: () async {
                              await SignalChatService().sendHelloMessage(
                                  chatController.room,
                                  chatController.room.getIdentity());
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
              SettingsSection(title: const Text('Message Relay'), tiles: [
                SettingsTile.navigation(
                  title: const Text('SendTo'),
                  leading: const Icon(CupertinoIcons.up_arrow),
                  value: Obx(() => textSmallGray(Get.context!,
                      chatController.roomContact.value.hisRelay ?? 'Not set')),
                  onPressed: (context) {
                    if (chatController.roomContact.value.hisRelay == null) {
                      Get.dialog(CupertinoAlertDialog(
                        title: const Text("Not set"),
                        content: Text(
                            '''${chatController.roomContact.value.displayName} does not set his ReceiveFrom, the message will be sent to all relays'''),
                        actions: <Widget>[
                          CupertinoDialogAction(
                              child: const Text(
                                'OK',
                              ),
                              onPressed: () async {
                                Get.back();
                              }),
                        ],
                      ));
                      return;
                    }
                    WebsocketService ws = Get.find<WebsocketService>();

                    RelayWebsocket? channel =
                        ws.channels[chatController.roomContact.value.hisRelay];

                    Get.dialog(CupertinoAlertDialog(
                      title: const Text("SendTo PostOffice"),
                      content:
                          Text('''${chatController.roomContact.value.hisRelay!}
Your messages will send to this server.'''),
                      actions: <Widget>[
                        CupertinoDialogAction(
                            child: const Text(
                              'Copy',
                            ),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(
                                  text: chatController
                                          .roomContact.value.hisRelay ??
                                      ''));
                              EasyLoading.showToast('Copied');
                              Get.back();
                            }),
                        channel == null
                            ? CupertinoDialogAction(
                                child: const Text(
                                  'Add',
                                ),
                                onPressed: () async {
                                  await RelayService().addAndConnect(
                                      chatController
                                          .roomContact.value.hisRelay!);
                                  EasyLoading.showToast('Success');
                                  Get.back();
                                })
                            : CupertinoDialogAction(
                                isDestructiveAction: true,
                                child: const Text(
                                  'Delete',
                                ),
                                onPressed: () async {
                                  await ContactService().updateHisRelay(
                                      chatController.roomContact.value.id,
                                      null);
                                  chatController.roomContact.value.hisRelay =
                                      null;
                                  chatController.roomContact.refresh();
                                  EasyLoading.showToast('Success');
                                  Get.back();
                                })
                      ],
                    ));
                  },
                ),
                SettingsTile.navigation(
                  title: const Text('ReceiveFrom'),
                  description: const Text(
                      'Using different PostOffice(relay server) for receiving and sending messages, tracking metadata will be more difficultly.'),
                  leading: const Icon(CupertinoIcons.down_arrow),
                  value: Obx(() => textSmallGray(Get.context!,
                      chatController.roomContact.value.myRelay ?? 'Not set')),
                  onPressed: (context) async {
                    String? relay = await Get.bottomSheet(SelectRoomRelay(
                        chatController.roomContact.value.myRelay));
                    if (relay == null) return;
                    chatController.roomContact.value.myRelay = relay;
                    chatController.roomContact.refresh();
                    await ContactService().updateMyRelay(
                        chatController.roomContact.value.id, relay);
                    EasyLoading.showToast('Success');
                    SignalChatService().sendRelaySyncMessage(
                        chatController.roomObs.value, relay);
                  },
                ),
              ]),
              if (receiveKeys.isNotEmpty)
                SettingsSection(
                    title: const Text('My Receive Addresses'),
                    tiles: receiveKeys
                        .map(
                          (e) => SettingsTile(
                            title: Text(e),
                          ),
                        )
                        .toList())
            ])));
  }
}
