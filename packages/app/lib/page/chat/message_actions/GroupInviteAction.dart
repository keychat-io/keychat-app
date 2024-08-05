import 'dart:convert' show jsonDecode;

import 'package:app/constants.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/keychat/room_profile.dart';
import 'package:app/models/models.dart';

import 'package:app/page/chat/message_actions/GroupInfoWidget.dart';
import 'package:app/service/GroupTx.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/kdf_group.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';

class GroupInviteAction extends StatelessWidget {
  final Message message;
  final Identity identity;
  const GroupInviteAction(this.message, this.identity, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (message.requestConfrim) {
      case RequestConfrimEnum.request:
        return OutlinedButton(
            onPressed: () async {
              EasyThrottle.throttle('joingroup', const Duration(seconds: 2),
                  () async {
                late RoomProfile roomProfile;

                roomProfile = RoomProfile.fromJson(jsonDecode(message.content));
                bool? accept = await Get.bottomSheet(
                    ignoreSafeArea: false,
                    isScrollControlled: true,
                    GroupInfoWidget(roomProfile, identity.secp256k1PKHex));
                if (accept == null) return;
                message.requestConfrim = accept == true
                    ? RequestConfrimEnum.approved
                    : RequestConfrimEnum.rejected;
                message.isRead = true;
                if (accept == false) {
                  await MessageService().updateMessageAndRefresh(message);
                  return;
                }
                Room? groupRoom;
                try {
                  // accept
                  EasyLoading.show(status: 'Loading...');
                  Isar database = DBProvider.database;
                  await database.writeTxn(() async {
                    await database.messages.put(message);
                    groupRoom =
                        await GroupTx().joinGroup(roomProfile, identity);
                  });
                  if (groupRoom == null) {
                    EasyLoading.dismiss();
                    EasyLoading.showError('Join group failed');
                    return;
                  }
                  if (groupRoom!.isShareKeyGroup) {
                    await GroupService().sendMessageToGroup(
                        groupRoom!, '${identity.displayName} joined group.',
                        subtype: KeyChatEventKinds.groupHi,
                        sentCallback: (res) {});
                  } else if (groupRoom!.isKDFGroup) {
                    await KdfGroupService.instance.sendHelloMessage(identity,
                        groupRoom!.getGroupSharedSignalId(), groupRoom!);
                  }
                  MessageService().refreshMessageInPage(message);
                  EasyLoading.showSuccess('Join group success');
                } catch (e, s) {
                  logger.e(e.toString(), error: e, stackTrace: s);
                  EasyLoading.showError('Join Group Error: ${e.toString()}',
                      duration: const Duration(seconds: 2));
                  return;
                }

                await Get.offAndToNamed('/room/${groupRoom!.id}',
                    arguments: groupRoom);
                await Get.find<HomeController>()
                    .loadIdentityRoomList(groupRoom!.identityId);
              });
            },
            child: const Text('Group Info >'));
      case RequestConfrimEnum.approved:
        return const Text('  Approved', style: TextStyle(color: Colors.green));
      case RequestConfrimEnum.rejected:
        return const Text('  Rejected', style: TextStyle(color: Colors.red));
      default:
        return Text(message.content);
    }
  }
}
