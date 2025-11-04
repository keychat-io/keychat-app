import 'dart:convert';

import 'package:keychat/controller/chat.controller.dart';
import 'package:keychat/models/message.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class SetRoomRelayAction extends StatelessWidget {
  const SetRoomRelayAction(this.cc, this.message, {super.key});
  final Message message;
  final ChatController cc;

  @override
  Widget build(BuildContext context) {
    switch (message.requestConfrim) {
      case RequestConfrimEnum.request:
        return Row(
          children: [
            OutlinedButton(
              onPressed: () {
                message.requestConfrim = RequestConfrimEnum.rejected;
                MessageService.instance.updateMessageAndRefresh(message);
              },
              child: const Text('Reject'),
            ),
            const SizedBox(width: 30),
            FilledButton(
              onPressed: () async {
                final relays = List<String>.from(jsonDecode(message.content));
                if (relays.isEmpty) {
                  EasyLoading.showToast('Invalid relay url');
                  return;
                }
                for (final relay in relays) {
                  if (!(relay.startsWith('ws://') ||
                      relay.startsWith('wss://'))) {
                    EasyLoading.showToast('Invalid relay url');
                    return;
                  }
                }

                final ws = Get.find<WebsocketService>();
                for (final relay in relays) {
                  if (ws.channels[relay] == null) {
                    RelayService.instance.addAndConnect(relay);
                  }
                }

                cc.roomObs.value.sendingRelays = relays;
                await RoomService.instance.updateRoomAndRefresh(
                  cc.roomObs.value,
                );

                message.requestConfrim = RequestConfrimEnum.approved;
                await MessageService.instance.updateMessageAndRefresh(message);
              },
              child: const Text('Approve'),
            ),
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
