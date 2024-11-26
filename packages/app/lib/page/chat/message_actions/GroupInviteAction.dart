import 'dart:convert' show jsonDecode;

import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/keychat/room_profile.dart';
import 'package:app/models/models.dart';

import 'package:app/page/chat/message_actions/GroupInfoWidget.dart';
import 'package:app/service/group_tx.dart';
import 'package:app/service/kdf_group.service.dart';
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
    switch (message.requestConfrim) {
      case RequestConfrimEnum.request:
        return FilledButton(
            onPressed: handleQuest, child: const Text('Group Info >'));
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

  handleQuest() async {
    EasyThrottle.throttle('joingroup', const Duration(seconds: 2), () async {
      RoomProfile roomProfile =
          RoomProfile.fromJson(jsonDecode(message.content));

      if (roomProfile.groupType == GroupType.kdf) {
        DateTime expiredAt =
            DateTime.fromMillisecondsSinceEpoch(roomProfile.updatedAt)
                .add(Duration(days: KeychatGlobal.kdfGroupKeysExpired));
        if (expiredAt.isBefore(DateTime.now())) {
          message.requestConfrim = RequestConfrimEnum.expired;
          message.isRead = true;
          await MessageService.instance.updateMessageAndRefresh(message);
          EasyLoading.showError('The invitation has expired');
          return;
        }
      }
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
        await MessageService.instance.updateMessageAndRefresh(message);
        return;
      }
      Room? groupRoom;
      try {
        EasyLoading.show(status: 'Loading...');
        Isar database = DBProvider.database;
        Room? exist = await database.rooms
            .filter()
            .toMainPubkeyEqualTo(
                roomProfile.oldToRoomPubKey ?? roomProfile.pubkey)
            .findFirst();
        if (exist != null) {
          // joined with another identity
          if (exist.identityId != identity.id) {
            message.requestConfrim = RequestConfrimEnum.rejected;
            await MessageService.instance.updateMessageAndRefresh(message);
            EasyLoading.showError(
                'You have joined this group with another identity',
                duration: const Duration(seconds: 3));
            return;
          }
          // duplicated invitation
          if (exist.version == roomProfile.updatedAt) {
            message.requestConfrim = RequestConfrimEnum.approved;
            await MessageService.instance.updateMessageAndRefresh(message);
            EasyLoading.showSuccess('The invitation has been auto proccessed',
                duration: const Duration(seconds: 3));
            return;
          }
          // expired invitation
          if (roomProfile.updatedAt < exist.version) {
            message.requestConfrim = RequestConfrimEnum.expired;
            await MessageService.instance.updateMessageAndRefresh(message);
            EasyLoading.showError('The invitation has expired',
                duration: const Duration(seconds: 3));
            return;
          }
          await RoomService.instance.deleteRoom(exist);
        }

        await database.writeTxn(() async {
          groupRoom =
              await GroupTx.instance.joinGroup(roomProfile, identity, message);
          await database.messages.put(message);
        });
        if (groupRoom == null) {
          EasyLoading.showError('Join group failed');
          return;
        }
      } catch (e, s) {
        String msg = Utils.getErrorMessage(e);
        logger.e(msg, error: e, stackTrace: s);
        EasyLoading.showError('Join Group Error: $msg',
            duration: const Duration(seconds: 3));
        return;
      }
      if (groupRoom != null) {
        try {
          if (groupRoom!.isKDFGroup) {
            await KdfGroupService.instance.sendHelloMessage(
                identity, groupRoom!.getGroupSharedSignalId(), groupRoom!);
          } else if (groupRoom!.isMLSGroup) {
            String? ext = roomProfile.ext;
            if (ext == null) {
              throw 'Welcome message is null';
            }
            groupRoom = await MlsGroupService.instance
                .acceptJoinGroup(identity, groupRoom!, ext);
          }

          await MessageService.instance.updateMessageAndRefresh(message);
          EasyLoading.showSuccess('Join group success');
        } catch (e, s) {
          RoomService.instance.deleteRoom(groupRoom!);
          message.requestConfrim = RequestConfrimEnum.request;
          await MessageService.instance.updateMessageAndRefresh(message);
          String msg = Utils.getErrorMessage(e);
          if (msg.contains('Error creating StagedWelcome from Welcome')) {
            msg =
                'PackageMessage is invalid, Contact the group admin, resend the invitation';
            await MlsGroupService.instance.uploadPKByIdentity(identity);
            message.requestConfrim = RequestConfrimEnum.expired;
            await MessageService.instance.updateMessageAndRefresh(message);
          }
          logger.e(msg, error: e, stackTrace: s);
          EasyLoading.showError('Join Group Error: $msg',
              duration: const Duration(seconds: 3));
          return;
        }

        await Get.offAndToNamed('/room/${groupRoom!.id}', arguments: groupRoom);
        Get.find<HomeController>().loadIdentityRoomList(groupRoom!.identityId);
      }
    });
  }
}
