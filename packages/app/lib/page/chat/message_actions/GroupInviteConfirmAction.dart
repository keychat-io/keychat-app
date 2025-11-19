import 'dart:convert' show jsonDecode;

import 'package:keychat/models/models.dart';
import 'package:keychat/service/group.service.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class GroupInviteConfirmAction extends StatelessWidget {
  const GroupInviteConfirmAction(this.senderName, this.message, {super.key});
  final Message message;
  final String senderName;

  @override
  Widget build(BuildContext context) {
    switch (message.requestConfrim) {
      case RequestConfrimEnum.request:
        return FilledButton(
          onPressed: () async {
            final list = jsonDecode(message.content) as List;

            final toMainPubkey = list[0] as String;

            final groupRoom = await RoomService.instance.getRoomByIdentity(
              toMainPubkey,
              message.identityId,
            );
            if (groupRoom == null) throw Exception('room not found');
            // List<RoomMember> members = await groupRoom.getActiveMembers();

            // members = members.length > 10 ? members.sublist(0, 10) : members;
            // int membersCount = members.length;
            final toJoinUserMap = Map<String, String>.from(
              list[1],
            ).map(MapEntry.new);

            Get.dialog(
              CupertinoAlertDialog(
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
                      MessageService.instance.updateMessageAndRefresh(message);
                      Get.back<void>();
                    },
                  ),
                  CupertinoDialogAction(
                    child: const Text('Confirm'),
                    onPressed: () async {
                      Get.back<void>();
                      try {
                        if (groupRoom.isMLSGroup) {
                          final users = <Map<String, dynamic>>[];
                          final invited = <String>[];
                          final pkIsNull = <String>[];

                          for (final entry in toJoinUserMap.entries) {
                            final pk = await MlsGroupService.instance
                                .getKeyPackageFromRelay(pubkey: entry.key);
                            if (pk == null) {
                              pkIsNull.add(entry.value);
                            } else {
                              invited.add(entry.value);
                            }

                            users.add({
                              'pubkey': entry.key,
                              'name': entry.value,
                              'mlsPK': pk,
                            });
                          }
                          if (invited.isEmpty) {
                            Get.dialog(
                              CupertinoAlertDialog(
                                title: const Text('Sent Invitation Failed'),
                                content: const Column(
                                  children: [
                                    Text(
                                      "All users's keyPackage is null, They need login app first.",
                                    ),
                                  ],
                                ),
                                actions: [
                                  CupertinoDialogAction(
                                    onPressed: Get.back,
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }
                          await MlsGroupService.instance.addMemeberToGroup(
                            groupRoom,
                            users,
                            senderName,
                          );
                          Get.dialog(
                            CupertinoAlertDialog(
                              title: const Text('Success'),
                              content: Column(
                                children: [
                                  Text(
                                    'Successfully invited: ${invited.join(',')}',
                                  ),
                                  if (pkIsNull.isNotEmpty)
                                    Text(
                                      'Failed to invite ${pkIsNull.join(',')}. They need login app first.',
                                    ),
                                ],
                              ),
                              actions: [
                                CupertinoDialogAction(
                                  onPressed: Get.back,
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          // for signal group
                          await GroupService.instance.inviteToJoinGroup(
                            groupRoom,
                            toJoinUserMap,
                          );
                          EasyLoading.showSuccess('Success');
                        }
                        message.requestConfrim = RequestConfrimEnum.approved;
                        MessageService.instance.updateMessageAndRefresh(
                          message,
                        );
                      } catch (e, s) {
                        final msg = Utils.getErrorMessage(e);
                        EasyLoading.showError(msg);
                        logger.e(msg, error: e, stackTrace: s);
                      }
                    },
                  ),
                ],
              ),
            );
          },
          child: const Text('To Confirm >'),
        );
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
