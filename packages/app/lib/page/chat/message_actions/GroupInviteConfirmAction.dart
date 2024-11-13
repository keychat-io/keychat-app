import 'dart:convert' show jsonDecode;

import 'package:app/models/models.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/kdf_group.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class GroupInviteConfirmAction extends StatelessWidget {
  final Message message;
  final String senderName;
  const GroupInviteConfirmAction(this.senderName, this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (message.requestConfrim) {
      case RequestConfrimEnum.request:
        return FilledButton(
            onPressed: () async {
              List list = jsonDecode(message.content);

              String toMainPubkey = list[0];

              Room? groupRoom = await RoomService()
                  .getRoomByIdentity(toMainPubkey, message.identityId);
              if (groupRoom == null) throw Exception('room not found');
              // List<RoomMember> members = await groupRoom.getActiveMembers();

              // members = members.length > 10 ? members.sublist(0, 10) : members;
              // int membersCount = members.length;
              Map<String, String> toJoinUserMap =
                  Map<String, String>.from(list[1])
                      .map((key, value) => MapEntry(key, value.toString()));

              Get.dialog(CupertinoAlertDialog(
                  title: Text('Group Name: ${groupRoom.name}'),
                  content: Column(
                    children: [
                      Text(message.realMessage ?? message.content),
                      // const SizedBox(height: 10),
                      // Text('Group Description: ${groupRoom.description}'),
                    ],
                  ),
                  actions: [
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      child: const Text('Reject'),
                      onPressed: () {
                        message.requestConfrim = RequestConfrimEnum.rejected;
                        MessageService().updateMessageAndRefresh(message);
                        Get.back();
                      },
                    ),
                    CupertinoDialogAction(
                        child: const Text('Confirm'),
                        onPressed: () async {
                          Get.back();
                          try {
                            if (groupRoom.isKDFGroup) {
                              await KdfGroupService.instance.inviteToJoinGroup(
                                  groupRoom, toJoinUserMap, senderName);
                            } else if (groupRoom.isMLSGroup) {
                              List<Map<String, dynamic>> users = [];
                              List<String> invited = [];
                              List<String> pkIsNull = [];

                              for (var entry in toJoinUserMap.entries) {
                                String? pk = await MlsGroupService.instance
                                    .getPK(entry.key);
                                if (pk == null) {
                                  pkIsNull.add(entry.value);
                                } else {
                                  invited.add(entry.value);
                                }

                                users.add({
                                  'pubkey': entry.key,
                                  'name': entry.value,
                                  'mlsPK': pk
                                });
                              }
                              if (invited.isEmpty) {
                                Get.dialog(CupertinoAlertDialog(
                                  title: const Text('Sent Invitation Failed'),
                                  content: const Column(
                                    children: [
                                      Text(
                                          'All users\'s keyPackage is null, They need login app first.'),
                                    ],
                                  ),
                                  actions: [
                                    CupertinoDialogAction(
                                      child: const Text('OK'),
                                      onPressed: () {
                                        Get.back();
                                      },
                                    ),
                                  ],
                                ));
                                return;
                              }
                              await MlsGroupService.instance.inviteToJoinGroup(
                                  groupRoom, users, senderName);
                              Get.dialog(CupertinoAlertDialog(
                                title: const Text('Successful'),
                                content: Column(
                                  children: [
                                    Text(
                                        'Successfully invited: ${invited.join(',')}'),
                                    if (pkIsNull.isNotEmpty)
                                      Text(
                                          'Failed to invite ${pkIsNull.join(',')}. They need login app first.'),
                                  ],
                                ),
                                actions: [
                                  CupertinoDialogAction(
                                    child: const Text('OK'),
                                    onPressed: () {
                                      Get.back();
                                    },
                                  ),
                                ],
                              ));
                            } else {
                              await GroupService()
                                  .inviteToJoinGroup(groupRoom, toJoinUserMap);
                              EasyLoading.showSuccess('Success');
                            }
                            message.requestConfrim =
                                RequestConfrimEnum.approved;
                            MessageService().updateMessageAndRefresh(message);
                          } catch (e, s) {
                            String msg = Utils.getErrorMessage(e);
                            EasyLoading.showError(msg);
                            logger.e(msg, error: e, stackTrace: s);
                          }
                        })
                  ]));
            },
            child: const Text('To Confirm >'));
      case RequestConfrimEnum.approved:
        return const Text('  Approved', style: TextStyle(color: Colors.green));
      case RequestConfrimEnum.rejected:
        return const Text('  Rejected', style: TextStyle(color: Colors.red));
      case RequestConfrimEnum.expired:
        return const Text('  Expired', style: TextStyle(color: Colors.black54));
      default:
        return Text(message.content);
    }
  }
}
