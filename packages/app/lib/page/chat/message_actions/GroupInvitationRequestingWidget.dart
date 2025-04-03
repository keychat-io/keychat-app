import 'dart:convert' show jsonDecode;

import 'package:app/controller/chat.controller.dart';
import 'package:app/models/keychat/group_invitation_request_model.dart';
import 'package:app/models/keychat/keychat_message.dart';
import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/page/chat/invite_member_to_mls.dart';
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
  final ChatController cc;
  final Message message;
  final Widget Function({Widget? child, String? text}) errorCallabck;
  const GroupInvitationRequestingWidget(
      this.cc, this.message, this.errorCallabck,
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
        leading: Utils.getAvatorByName(map.name,
            backgroudColors: [const Color(0xffEC6E0E), const Color(0xffDF4D9E)],
            borderRadius: 12),
        title: Text('Request to join Group: ${map.name}',
            style: Theme.of(context).textTheme.titleSmall),
        subtitle: textSmallGray(context, 'Pubkey: ${map.roomPubkey}'),
        onTap: () async {
          if (message.requestConfrim == RequestConfrimEnum.approved) {
            EasyLoading.showToast('Proccessed');
            return;
          }
          Room? groupRoom = await RoomService.instance.getRoomByIdentity(
              map.roomPubkey, cc.roomObs.value.getIdentity().id);
          if (groupRoom == null) {
            EasyLoading.showToast('Group not found');
            return;
          }
          if (map.myPubkey == cc.roomObs.value.myIdPubkey) {
            EasyLoading.showToast('It\'s your message');
            return;
          }
          // bulk to proccess multi requesting
          String? requestId = message.requestId;
          if (requestId != null) {
            List<Message> requests =
                await MessageService.instance.getMessageByRequestId(requestId);
            if (requests.length >= 2) {
              Get.bottomSheet(InviteMemberToMLS(groupRoom, requests),
                  isScrollControlled: true, ignoreSafeArea: false);
              return;
            }
          }
          Get.dialog(CupertinoAlertDialog(
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
                child: const Text('Send Invite'),
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

                      await MlsGroupService.instance.addMemeberToGroup(
                          groupRoom,
                          users,
                          cc.roomObs.value.getIdentity().displayName);

                      message.requestConfrim = RequestConfrimEnum.approved;
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
