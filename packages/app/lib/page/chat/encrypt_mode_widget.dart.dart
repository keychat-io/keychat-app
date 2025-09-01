import 'package:app/controller/chat.controller.dart';
import 'package:app/models/room.dart';
import 'package:app/page/components.dart';
import 'package:app/service/signal_chat.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../service/room.service.dart';

class EncryptModeWidget extends StatelessWidget {
  final ChatController cc;
  const EncryptModeWidget({super.key, required this.cc});

  @override
  Widget build(BuildContext context) {
    var signalIntro = [
      '''✅ 1. Anti-Forgery
✅ 2. End-to-End Encryption
✅ 3. Forward Secrecy
✅ 4. Backward Secrecy
✅ 5. Metadata Privacy'''
    ];

    var nostrIntro = [
      '''✅ 1. Anti-Forgery
✅ 2. End-to-End Encryption
❌ 3. Forward Secrecy
❌ 4. Backward Secrecy
❌ 5. Metadata Privacy'''
    ];

    return Padding(
      padding: const EdgeInsets.only(right: 10, left: 10),
      child: Column(children: [
        Card(
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Flex(
            direction: Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => ListTile(
                    title: Text('Signal Protocol',
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: const Text('Security and Privacy Level: ⭐⭐⭐⭐⭐'),
                    leading: Radio<EncryptMode>(
                        value: EncryptMode.signal,
                        groupValue: cc.roomObs.value.encryptMode,
                        onChanged: handleClick),
                    onTap: () {
                      handleClick(EncryptMode.signal);
                    },
                  )),
              ...(signalIntro.map((e) => textSmallGray(context, e)).toList()),
            ],
          ),
        )),
        Card(
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => ListTile(
                    title: Text('Nostr nip17 Protocol',
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: const Text('Security and Privacy Level: ⭐'),
                    leading: Radio<EncryptMode>(
                        value: EncryptMode.nip04,
                        groupValue: cc.roomObs.value.encryptMode,
                        onChanged: handleClick),
                    onTap: () {
                      handleClick(EncryptMode.nip04);
                    },
                  )),
              ...(nostrIntro.map((e) => textSmallGray(context, e)).toList()),
            ],
          ),
        )),
      ]),
    );
  }

  Future<void> handleClick(EncryptMode? mode) async {
    if (mode == null) return;
    Room room = cc.roomObs.value;
    if (mode == EncryptMode.signal &&
        room.type == RoomType.common &&
        room.toMainPubkey == room.myIdPubkey) {
      EasyLoading.showError('Can\'t switch to signal mode with yourself');
      return;
    }
    if (mode == EncryptMode.signal && room.curve25519PkHex == null) {
      await SignalChatService.instance
          .sendHelloMessage(room, room.getIdentity());
      Get.back();
      Get.back();
      Get.back(); // back to room page
      EasyLoading.showSuccess('Send Request Successfully');
      return;
    }
    cc.roomObs.value.encryptMode = mode;
    await RoomService.instance.updateRoom(cc.roomObs.value);
    cc.roomObs.refresh();
    EasyLoading.showSuccess('Switch successfully');
  }
}
