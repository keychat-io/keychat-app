import 'dart:convert';

import 'package:app/controller/chat.controller.dart';
import 'package:app/models/keychat/keychat_message.dart';
import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/page/common.dart';
import 'package:app/service/room.service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class GroupInvitationInfoWidget extends StatelessWidget {
  final ChatController chatController;
  final Message message;
  final Widget Function({Widget? child, String? text}) errorCallabck;
  const GroupInvitationInfoWidget(
      this.chatController, this.message, this.errorCallabck,
      {super.key});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> map;
    try {
      KeychatMessage keychatMessage =
          KeychatMessage.fromJson(jsonDecode(message.content));
      map = jsonDecode(keychatMessage.name!);
    } catch (e) {
      return errorCallabck(text: message.content);
    }

    return Card(
      child: ListTile(
        leading: getAvatorByName(map['name'], nameLength: 3),
        title: Text('Group Name: ${map['name']}',
            style:
                TextStyle(fontSize: 16, color: Theme.of(context).primaryColor)),
        subtitle: Text('ID: ${map['pubkey']}'),
        onTap: () async {
          Room? exist = await RoomService.instance.getRoomByIdentity(
              map['pubkey'], chatController.roomObs.value.identityId);
          if (exist != null) {
            if (exist.id == chatController.room.id) {
              EasyLoading.showToast('You are already in this group');
              return;
            }
            Get.dialog(CupertinoAlertDialog(
              title: Text('Go to: ${exist.name!}'),
              actions: <Widget>[
                CupertinoDialogAction(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('Go'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await Get.toNamed('/room/${exist.id}', arguments: exist);
                  },
                ),
              ],
            ));
            return;
          }
          Get.dialog(CupertinoAlertDialog(
            title: const Text('Join Group'),
            content: const Text('Do you want to join the group?'),
            actions: <Widget>[
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Join'),
                onPressed: () async {
                  Get.back();
                },
              ),
            ],
          ));
        },
      ),
    );
  }
}
