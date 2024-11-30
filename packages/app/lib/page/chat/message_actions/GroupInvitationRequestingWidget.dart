import 'dart:convert' show jsonDecode;

import 'package:app/controller/chat.controller.dart';
import 'package:app/models/keychat/group_invitation_request_model.dart';
import 'package:app/models/keychat/keychat_message.dart';
import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/page/common.dart';
import 'package:app/page/components.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class GroupInvitationRequestingWidget extends StatelessWidget {
  final ChatController chatController;
  final Message message;
  final Widget Function({Widget? child, String? text}) errorCallabck;
  const GroupInvitationRequestingWidget(
      this.chatController, this.message, this.errorCallabck,
      {super.key});

  @override
  Widget build(BuildContext context) {
    GroupInvitationRequestModel map;
    try {
      KeychatMessage keychatMessage =
          KeychatMessage.fromJson(jsonDecode(message.content));
      map = GroupInvitationRequestModel.fromJson(
          jsonDecode(keychatMessage.name!));
    } catch (e) {
      return errorCallabck(text: message.content);
    }

    return Card(
      child: ListTile(
        leading: getAvatorByName(map.name, nameLength: 3),
        title: Text('Request to join Group: ${map.name}',
            style:
                TextStyle(fontSize: 16, color: Theme.of(context).primaryColor)),
        subtitle: textSmallGray(context, 'Pubkey: ${map.roomPubkey}'),
        onTap: () async {
          if (message.requestConfrim == RequestConfrimEnum.approved) {
            EasyLoading.showToast('Proccessed');
            return;
          }
          Room? groupRoom = await RoomService.instance.getRoomByIdentity(
              map.roomPubkey, chatController.room.getIdentity().id);
          if (groupRoom == null) {
            EasyLoading.showToast('Group not found');
            return;
          }
          if (map.myPubkey == chatController.room.myIdPubkey) {
            EasyLoading.showToast('It\'s your message');
            return;
          }

          Get.dialog(CupertinoAlertDialog(
            title: const Text('Approve Requesting'),
            content: Text('Join the Group: ${map.name}'),
            actions: <Widget>[
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () {
                  Get.back();
                },
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Approve'),
                onPressed: () async {
                  EasyThrottle.throttle(
                      'sendJoinGroupRequest', const Duration(seconds: 5),
                      () async {
                    try {
                      List<Map<String, dynamic>> users = [
                        {
                          'pubkey': map.myPubkey,
                          'name': map.myName,
                          'mlsPK': map.mlsPK
                        }
                      ];

                      await MlsGroupService.instance.inviteToJoinGroup(
                          groupRoom,
                          users,
                          chatController.room.getIdentity().displayName);

                      message.requestConfrim = RequestConfrimEnum.expired;
                      message.isRead = true;
                      await MessageService.instance
                          .updateMessageAndRefresh(message);

                      EasyLoading.showSuccess('Success');
                    } catch (e, s) {
                      String msg = Utils.getErrorMessage(e);
                      EasyLoading.showError('Error: $msg');
                      logger.e(msg, error: e, stackTrace: s);
                    }
                    Get.back();
                  });
                },
              ),
            ],
          ));
        },
      ),
    );
  }
}
