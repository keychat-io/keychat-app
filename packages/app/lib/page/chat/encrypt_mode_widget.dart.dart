import 'package:keychat/controller/chat.controller.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/signal_chat.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:keychat/service/room.service.dart';

class EncryptModeWidget extends StatelessWidget {
  const EncryptModeWidget({required this.cc, super.key});
  final ChatController cc;

  @override
  Widget build(BuildContext context) {
    final signalIntro = [
      '''
✅ 1. Anti-Forgery
✅ 2. End-to-End Encryption
✅ 3. Forward Secrecy
✅ 4. Backward Secrecy
✅ 5. Metadata Privacy''',
    ];

    final nostrIntro = [
      '''
✅ 1. Anti-Forgery
✅ 2. End-to-End Encryption
❌ 3. Forward Secrecy
❌ 4. Backward Secrecy
❌ 5. Metadata Privacy''',
    ];

    return Padding(
      padding: const EdgeInsets.only(right: 10, left: 10),
      child: RadioGroup<EncryptMode>(
        groupValue: cc.roomObs.value.encryptMode,
        onChanged: handleClick,
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Flex(
                  direction: Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(
                      () => ListTile(
                        title: Text(
                          'Signal Protocol',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: const Text(
                          'Security and Privacy Level: ⭐⭐⭐⭐⭐',
                        ),
                        leading: const Radio<EncryptMode>(
                          value: EncryptMode.signal,
                        ),
                        onTap: () {
                          handleClick(EncryptMode.signal);
                        },
                      ),
                    ),
                    ...(signalIntro
                        .map((e) => textSmallGray(context, e))
                        .toList()),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(
                      () => ListTile(
                        title: Text(
                          'Nostr nip17 Protocol',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: const Text('Security and Privacy Level: ⭐'),
                        leading: const Radio<EncryptMode>(
                          value: EncryptMode.nip04,
                        ),
                        onTap: () {
                          handleClick(EncryptMode.nip04);
                        },
                      ),
                    ),
                    ...(nostrIntro
                        .map((e) => textSmallGray(context, e))
                        .toList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> handleClick(EncryptMode? mode) async {
    if (mode == null) return;
    final room = cc.roomObs.value;
    if (mode == EncryptMode.signal &&
        room.type == RoomType.common &&
        room.toMainPubkey == room.myIdPubkey) {
      EasyLoading.showError("Can't switch to signal mode with yourself");
      return;
    }
    if (mode == EncryptMode.signal && room.curve25519PkHex == null) {
      await SignalChatService.instance.sendHelloMessage(
        room,
        room.getIdentity(),
      );
      await ContactService.instance.addContactToFriend(
        pubkey: room.toMainPubkey,
        identityId: room.identityId,
      );
      Get
        ..back<void>()
        ..back<void>()
        ..back<void>(); // back to room page
      EasyLoading.showSuccess('Send Request Successfully');
      return;
    }
    cc.roomObs.value.encryptMode = mode;
    await RoomService.instance.updateRoom(cc.roomObs.value);
    cc.roomObs.refresh();
    EasyLoading.showSuccess('Switch successfully');
  }
}
