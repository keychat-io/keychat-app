import 'package:app/controller/chat.controller.dart';
import 'package:app/models/message.dart';
import 'package:app/models/relay.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/relay.service.dart';
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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            OutlinedButton(
                onPressed: () {
                  message.requestConfrim = RequestConfrimEnum.rejected;
                  MessageService().updateMessageAndRefresh(message);
                },
                child: const Text('Reject')),
            const SizedBox(
              width: 30,
            ),
            FilledButton(
                onPressed: () async {
                  if (!(message.content.startsWith('ws://') ||
                      message.content.startsWith('wss://'))) {
                    EasyLoading.showToast('Invalid relay url');
                    return;
                  }
                  WebsocketService ws = Get.find<WebsocketService>();
                  if (ws.channels[message.content] == null) {
                    EasyLoading.showToast('Start connecting a new relay');
                    await RelayService().addAndConnect(message.content);
                  } else {
                    if (ws.channels[message.content]!.relay.active == false) {
                      EasyLoading.showToast('Please enable this relay first');
                      return;
                    }
                    if (ws.channels[message.content]!.channelStatus !=
                        RelayStatusEnum.success) {
                      EasyLoading.showToast(
                          'Your sendTo PostOffice is not connected, please try again later');
                      return;
                    }
                  }
                  await ContactService().updateHisRelay(
                      chatController.roomContact.value.id, message.content);

                  chatController.roomContact.value.hisRelay = message.content;
                  chatController.roomContact.refresh();

                  message.requestConfrim = RequestConfrimEnum.approved;
                  MessageService().updateMessageAndRefresh(message);
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
