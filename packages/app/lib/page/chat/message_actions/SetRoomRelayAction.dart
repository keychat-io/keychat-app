import 'dart:convert';

import 'package:app/controller/chat.controller.dart';
import 'package:app/models/message.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class SetRoomRelayAction extends StatelessWidget {
  final Message message;
  final ChatController chatController;
  const SetRoomRelayAction(this.chatController, this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (message.requestConfrim) {
      case RequestConfrimEnum.request:
        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            OutlinedButton(
                onPressed: () {
                  message.requestConfrim = RequestConfrimEnum.rejected;
                  MessageService().updateMessageAndRefresh(message);
                },
                child: const Text('Reject')),
            const SizedBox(width: 30),
            FilledButton(
                onPressed: () async {
                  List<String> relays =
                      List<String>.from(jsonDecode(message.content));
                  if (relays.isEmpty) {
                    EasyLoading.showToast('Invalid relay url');
                    return;
                  }
                  for (var relay in relays) {
                    if (!(relay.startsWith('ws://') ||
                        relay.startsWith('wss://'))) {
                      EasyLoading.showToast('Invalid relay url');
                      return;
                    }
                  }

                  WebsocketService ws = Get.find<WebsocketService>();
                  for (var relay in relays) {
                    if (ws.channels[relay] == null) {
                      RelayService().addAndConnect(relay);
                    }
                  }

                  chatController.roomObs.value.sendingRelays = relays;
                  await RoomService()
                      .updateChatRoomPage(chatController.roomObs.value);

                  message.requestConfrim = RequestConfrimEnum.approved;
                  await MessageService().updateMessageAndRefresh(message);
                },
                child: const Text('Approve'))
          ],
        );
      case RequestConfrimEnum.approved:
        return const Text('  Approved', style: TextStyle(color: Colors.green));
      case RequestConfrimEnum.rejected:
        return const Text('  Rejected', style: TextStyle(color: Colors.red));
      default:
        return Text(message.requestConfrim?.name ?? '');
    }
  }
}
