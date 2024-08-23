import 'dart:convert';

import 'package:app/models/models.dart';
import 'package:app/service/room.service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'GroupInviteConfirmPage.dart';

class GroupInviteConfirmAction extends StatelessWidget {
  final Message message;
  const GroupInviteConfirmAction(this.message, {super.key});

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
              List<RoomMember> members = await groupRoom.getActiveMembers();

              members = members.length > 10 ? members.sublist(0, 10) : members;
              int membersCount = members.length;
              Map<String, String> toJoinUserMap =
                  Map<String, String>.from(list[1])
                      .map((key, value) => MapEntry(key, value.toString()));

              Get.to(() => GroupInviteConfirmPage(
                  message: message,
                  groupRoom: groupRoom,
                  members: members,
                  membersCount: membersCount,
                  toJoinUserMap: toJoinUserMap));
            },
            child: const Text('To Confirm >'));
      case RequestConfrimEnum.approved:
        return const Text('  Approved', style: TextStyle(color: Colors.green));
      case RequestConfrimEnum.rejected:
        return const Text('  Rejected', style: TextStyle(color: Colors.red));
      default:
        return Text(message.content);
    }
  }
}
