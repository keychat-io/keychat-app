import 'package:app/controller/chat.controller.dart';
import 'package:app/models/room.dart';
import 'package:app/page/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../service/room.service.dart';

class EncryptModeWidget extends StatelessWidget {
  final ChatController chatController;
  const EncryptModeWidget({super.key, required this.chatController});

  @override
  Widget build(BuildContext context) {
    var signalIntro = [
      'Signal Protocol is a well-known encryption protocol. It is used by Signal, WhatsApp, and many other apps.',
      '✅Encryption key: A one-time key for each message',
      '✅Sender address: Another one-time key',
      '✅Recipient address: A one-time key of each round conversation',
      '✅Impact of leaking private key: Leaking one message'
    ];

    var nostrIntro = [
      'It\'s an end-to-end encryption technology. Use this to chat with other nostr clients.',
      '❌Encryption key, Sender address, Recipient address: immutable',
      '❌Without metadata protection, servers can analyze the sender and recipient of messages, as well as the frequency of communication.',
      '❌Impact of leaking private key: Leaking all message'
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
                        groupValue: chatController.roomObs.value.encryptMode,
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
                    title: Text('Nostr nip04 Protocol',
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: const Text('Security and Privacy Level: ⭐'),
                    leading: Radio<EncryptMode>(
                        value: EncryptMode.nip04,
                        groupValue: chatController.roomObs.value.encryptMode,
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

  handleClick(EncryptMode? mode) async {
    Room room = chatController.roomObs.value;
    if (mode == null) return;
    if (mode == EncryptMode.signal &&
        room.type == RoomType.common &&
        room.toMainPubkey == chatController.room.myIdPubkey) {
      EasyLoading.showError('Can\'t switch to signal mode with yourself');
      return;
    }
    chatController.roomObs.value.encryptMode = mode;
    await RoomService().updateRoom(chatController.roomObs.value);
    chatController.roomObs.refresh();
    EasyLoading.showInfo('Switch successfully');
  }
}
