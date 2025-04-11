import 'package:app/page/chat/SelectRoomRelay.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/contact.service.dart';
import 'package:easy_debounce/easy_throttle.dart';
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

class ChatSettingSecurity extends StatelessWidget {
  final int? roomId;
  const ChatSettingSecurity({super.key, this.roomId});
  @override
  Widget build(BuildContext context) {
    int id = roomId ?? int.parse(Get.parameters['id']!);
    ChatController cc = RoomService.getController(id)!;

    List<String> receiveKeys =
        ContactService.instance.getMyReceiveKeys(cc.roomObs.value) ?? [];
    return Scaffold(
        appBar:
            AppBar(centerTitle: true, title: const Text('Security Settings')),
        body: Obx(() => SettingsList(platform: DevicePlatform.iOS, sections: [
              SettingsSection(
                  title: const Text('Message Encrypt Protocol'),
                  tiles: [
                    SettingsTile(
                        title: const Text('Encrypt mode'),
                        leading: const Icon(CupertinoIcons.lock),
                        value:
                            cc.roomObs.value.encryptMode == EncryptMode.signal
                                ? textP('Signal procotol', color: Colors.green)
                                : textP('Nostr nip17', color: Colors.red)),
                    SettingsTile.navigation(
                      title: const Text('Reset Signal Session'),
                      leading: const Icon(CupertinoIcons.refresh),
                      onPressed: (value) async {
                        Get.dialog(CupertinoAlertDialog(
                          title: const Text('Send request '),
                          content: const Text(
                              'Waiting for your friend comes online and approve'),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('OK'),
                              onPressed: () async {
                                Get.back();
                                EasyThrottle.throttle('ResetSessionStatus',
                                    const Duration(seconds: 3), () async {
                                  await Get.find<ChatxService>()
                                      .deleteSignalSessionKPA(cc
                                          .roomObs.value); // delete old session
                                  await SignalChatService.instance
                                      .sendHelloMessage(cc.roomObs.value,
                                          cc.roomObs.value.getIdentity(),
                                          greeting:
                                              'Reset signal session status');

                                  EasyLoading.showInfo(
                                      'Request sent successfully.');
                                });
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
                  value: Obx(() => cc.roomObs.value.sendingRelays.isEmpty
                      ? const Text('All Relays')
                      : Flexible(
                          child: Text(cc.roomObs.value.sendingRelays.isNotEmpty
                              ? cc.roomObs.value.sendingRelays.join(',')
                              : ''))),
                  onPressed: (c) {
                    if (cc.roomObs.value.sendingRelays.isEmpty) {
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
                            cc.roomObs.value.receivingRelays = [];
                            await RoomService.instance
                                .updateRoomAndRefresh(cc.roomObs.value);
                            EasyLoading.showToast('Save Success');
                            Get.back();
                          },
                          child: const Text('Delete'),
                        )
                      ],
                    ));
                  },
                ),
                if (cc.roomObs.value.type != RoomType.bot)
                  SettingsTile.navigation(
                    title: const Text('ReceiveFrom'),
                    leading: const Icon(CupertinoIcons.down_arrow),
                    description: Obx(() => Text(
                        cc.roomObs.value.receivingRelays.isNotEmpty
                            ? cc.roomObs.value.receivingRelays.join(',')
                            : '')),
                    onPressed: (context) async {
                      List<String>? relays = await Get.bottomSheet(
                          SelectRoomRelay(cc.roomObs.value.receivingRelays));
                      if (relays == null) return;
                      cc.roomObs.value.receivingRelays = relays;
                      await RoomService.instance
                          .updateRoomAndRefresh(cc.roomObs.value);
                      await SignalChatService.instance
                          .sendRelaySyncMessage(cc.roomObs.value, relays);
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
