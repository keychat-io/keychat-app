import 'dart:convert' show jsonDecode;

import 'package:app/controller/chat.controller.dart';
import 'package:app/models/keychat/group_invitation_model.dart';
import 'package:app/models/keychat/keychat_message.dart';
import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
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

class GroupInvitationInfoWidget extends StatelessWidget {
  final ChatController cc;
  final Message message;
  final Widget Function({Widget? child, String? text}) errorCallabck;
  const GroupInvitationInfoWidget(this.cc, this.message, this.errorCallabck,
      {super.key});

  @override
  Widget build(BuildContext context) {
    GroupInvitationModel map;
    try {
      KeychatMessage keychatMessage =
          KeychatMessage.fromJson(jsonDecode(message.content));
      map = GroupInvitationModel.fromJson(jsonDecode(keychatMessage.name!));
    } catch (e) {
      return errorCallabck(text: message.content);
    }

    return Card(
      child: ListTile(
        leading: Utils.getAvatorByName(map.name,
            backgroudColors: [const Color(0xffEC6E0E), const Color(0xffDF4D9E)],
            borderRadius: 12),
        title: Text('Group Invitation: ${map.name}',
            style: Theme.of(context).textTheme.titleSmall),
        subtitle: textSmallGray(context, 'Click to join group'),
        onTap: () async {
          if (message.requestConfrim == RequestConfrimEnum.approved) {
            EasyLoading.showToast('Proccessed');
            return;
          }

          Room? exist = await RoomService.instance
              .getRoomByIdentity(map.pubkey, cc.roomObs.value.identityId);
          if (exist != null) {
            if (exist.id == cc.roomObs.value.id) {
              EasyLoading.showToast('You are already in this group');
              return;
            }
            Get.dialog(CupertinoAlertDialog(
              title: Text('Group Room: ${exist.name!}'),
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
                    await Utils.toNamedRoom(exist);
                  },
                ),
              ],
            ));
            return;
          }
          Get.dialog(CupertinoAlertDialog(
            title: Text('Join Group: ${map.name}?'),
            content: const Text('Waiting approve by the inviter.'),
            actions: <Widget>[
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () {
                  Get.back();
                },
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Send Request'),
                onPressed: () async {
                  EasyThrottle.throttle(
                      'sendJoinGroupRequest', const Duration(seconds: 5),
                      () async {
                    try {
                      await MlsGroupService.instance.sendJoinGroupRequest(
                          map, cc.roomObs.value.getIdentity());
                      EasyLoading.showSuccess('Request sent');
                      // proccess message status
                      message.requestConfrim = RequestConfrimEnum.approved;
                      message.isRead = true;
                      await MessageService.instance
                          .updateMessageAndRefresh(message);
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
