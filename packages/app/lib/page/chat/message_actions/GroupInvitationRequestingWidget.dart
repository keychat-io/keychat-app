import 'dart:convert' show jsonDecode;

import 'package:keychat/controller/chat.controller.dart';
import 'package:keychat/exceptions/expired_members_exception.dart';
import 'package:keychat/models/keychat/group_invitation_request_model.dart';
import 'package:keychat/models/keychat/keychat_message.dart';
import 'package:keychat/models/message.dart';
import 'package:keychat/page/chat/expired_members_dialog.dart';
import 'package:keychat/page/chat/invite_member_to_mls.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class GroupInvitationRequestingWidget extends StatelessWidget {
  const GroupInvitationRequestingWidget(
    this.cc,
    this.message,
    this.errorCallabck, {
    super.key,
  });
  final ChatController cc;
  final Message message;
  final Widget Function({Widget? child, String? text}) errorCallabck;

  @override
  Widget build(BuildContext context) {
    GroupInvitationRequestModel map;
    try {
      final keychatMessage = KeychatMessage.fromJson(
        jsonDecode(message.content) as Map<String, dynamic>,
      );
      map = GroupInvitationRequestModel.fromJson(
        jsonDecode(keychatMessage.name!) as Map<String, dynamic>,
      );
    } catch (e) {
      return errorCallabck(text: message.content);
    }

    return Card(
      child: ListTile(
        leading: Utils.getAvatorByName(
          map.name,
          backgroudColors: [const Color(0xffEC6E0E), const Color(0xffDF4D9E)],
          borderRadius: 12,
        ),
        title: Text(
          'Request to join Group: ${map.name}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: textSmallGray(context, 'Pubkey: ${map.roomPubkey}'),
        onTap: () async {
          if (message.requestConfrim == RequestConfrimEnum.approved) {
            EasyLoading.showToast('Proccessed');
            return;
          }
          final groupRoom = await RoomService.instance.getRoomByIdentity(
            map.roomPubkey,
            cc.roomObs.value.getIdentity().id,
          );
          if (groupRoom == null) {
            EasyLoading.showToast('Group not found');
            return;
          }
          if (map.myPubkey == cc.roomObs.value.myIdPubkey) {
            EasyLoading.showToast("It's your message");
            return;
          }
          // bulk to proccess multi requesting
          final requestId = message.requestId;
          if (requestId != null) {
            final requests = await MessageService.instance
                .getMessageByRequestId(requestId);
            if (requests.length >= 2) {
              Get.bottomSheet(
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
                InviteMemberToMLS(groupRoom, requests),
                isScrollControlled: true,
                ignoreSafeArea: false,
              );
              return;
            }
          }
          Get.dialog(
            CupertinoAlertDialog(
              content: Text('Join the Group: ${map.name}'),
              actions: <Widget>[
                CupertinoDialogAction(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Get.back<void>();
                  },
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('Send Invite'),
                  onPressed: () async {
                    EasyThrottle.throttle(
                      'sendJoinGroupRequest',
                      const Duration(seconds: 5),
                      () async {
                        try {
                          final users = <Map<String, dynamic>>[
                            {
                              'pubkey': map.myPubkey,
                              'name': map.myName,
                              'mlsPK': map.mlsPK,
                            },
                          ];

                          await MlsGroupService.instance.addMemeberToGroup(
                            groupRoom,
                            users,
                            cc.roomObs.value.getIdentity().displayName,
                          );

                          message.requestConfrim = RequestConfrimEnum.approved;
                          message.isRead = true;
                          await MessageService.instance.updateMessageAndRefresh(
                            message,
                          );

                          EasyLoading.showSuccess('Success');
                        } on ExpiredMembersException catch (e) {
                          Get.back<void>();
                          await Future<void>.delayed(
                            const Duration(milliseconds: 100),
                          );
                          Get.dialog<void>(
                            ExpiredMembersDialog(
                              expiredMembers: e.expiredMembers,
                              room: groupRoom,
                            ),
                          );
                          return;
                        } catch (e, s) {
                          final msg = Utils.getErrorMessage(e);
                          EasyLoading.showError('Error: $msg');
                          logger.e(msg, error: e, stackTrace: s);
                        }
                        Get.back<void>();
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
