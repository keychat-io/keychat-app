import 'dart:convert' show jsonDecode;

import 'package:app/constants.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr_event.dart';

import 'package:app/page/chat/message_actions/GroupInfoWidget.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/room.service.dart';
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
    logger.d('GroupInviteAction: ${message.content} ${message.requestConfrim}');
    switch (message.requestConfrim) {
      case RequestConfrimEnum.request:
        return FilledButton(
            onPressed: handlRequest, child: const Text('Group Info >'));
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

  handlRequest() async {
    EasyThrottle.throttle('joingroup', const Duration(seconds: 2), () async {
      NostrEventModel subEvent =
          NostrEventModel.fromJson(jsonDecode(message.content));

      bool? accept = await Get.bottomSheet(
          ignoreSafeArea: false,
          isScrollControlled: true,
          GroupInfoWidget(subEvent, identity.secp256k1PKHex));
      if (accept == null) return;
      message.requestConfrim = accept == true
          ? RequestConfrimEnum.approved
          : RequestConfrimEnum.rejected;

      message.isRead = true;
      if (accept == false) {
        await MessageService.instance.updateMessageAndRefresh(message);
        return;
      }
      Room? groupRoom;
      String? groupId = subEvent.getTagByKey(EventKindTags.nip104Group);
      if (groupId == null) {
        EasyLoading.showError('Group ID is missing');
        return;
      }
      try {
        EasyLoading.show(status: 'Loading...');
        Isar database = DBProvider.database;
        Room? exist = await database.rooms
            .filter()
            .toMainPubkeyEqualTo(groupId)
            .identityIdEqualTo(identity.id)
            .findFirst();
        if (exist != null) {
          if (exist.identityId != identity.id) {
            message.requestConfrim = RequestConfrimEnum.rejected;
            await MessageService.instance.updateMessageAndRefresh(message);
            EasyLoading.showError(
                'You have joined this group with another identity',
                duration: const Duration(seconds: 3));
            return;
          }
          // duplicated invitation
          if (exist.version == subEvent.createdAt) {
            message.requestConfrim = RequestConfrimEnum.approved;
            await MessageService.instance.updateMessageAndRefresh(message);
            EasyLoading.showSuccess('The invitation has been auto proccessed',
                duration: const Duration(seconds: 3));
            return;
          }
          // expired invitation
          if (subEvent.createdAt < exist.version) {
            message.requestConfrim = RequestConfrimEnum.expired;
            await MessageService.instance.updateMessageAndRefresh(message);
            EasyLoading.showError('The invitation has expired',
                duration: const Duration(seconds: 3));
            return;
          }
          await RoomService.instance.deleteRoom(exist);
        }

        groupRoom = await MlsGroupService.instance.createRoomFromInvitation(
            subEvent, identity, message,
            groupId: groupId);

        await Get.offAndToNamed('/room/${groupRoom.id}', arguments: groupRoom);
        Get.find<HomeController>().loadIdentityRoomList(groupRoom.identityId);
      } catch (e, s) {
        message.requestConfrim = RequestConfrimEnum.request;
        await MessageService.instance.updateMessageAndRefresh(message);
        String msg = Utils.getErrorMessage(e);
        if (msg.contains('Error creating StagedWelcome from Welcome')) {
          msg =
              'PackageMessage is invalid, Contact the group admin, resend the invitation';
          await MlsGroupService.instance.uploadKeyPackages([identity]);
          message.requestConfrim = RequestConfrimEnum.expired;
          await MessageService.instance.updateMessageAndRefresh(message);
        }
        logger.e(msg, error: e, stackTrace: s);
        EasyLoading.showError('Join Group Error: $msg',
            duration: const Duration(seconds: 3));
        return;
      }
    });
  }
}
