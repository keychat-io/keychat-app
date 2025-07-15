import 'dart:convert' show jsonDecode;

import 'package:app/constants.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr_event.dart';

import 'package:app/page/chat/message_actions/GroupInfoWidget.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
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
      String? groupId = subEvent.getTagByKey(EventKindTags.pubkey);
      if (groupId == null) {
        EasyLoading.showError('Group ID is missing');
        return;
      }
      bool? accept = await Get.bottomSheet(
          GroupInfoWidget(subEvent, identity.secp256k1PKHex, groupId));
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
        EasyLoading.show(status: 'Processing...');
        Isar database = DBProvider.database;
        Room? exist = await database.rooms
            .filter()
            .toMainPubkeyEqualTo(groupId)
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

        groupRoom = await MlsGroupService.instance.createGroupFromInvitation(
            subEvent, identity, message,
            groupId: groupId);
        EasyLoading.dismiss();
        MlsGroupService.instance
            .uploadKeyPackages(identities: [identity], forceUpload: true);
      } catch (e, s) {
        String msg = Utils.getErrorMessage(e);
        logger.e(msg, error: e, stackTrace: s);

        // handle error to rollback the room
        Room? room =
            await RoomService.instance.getRoomByIdentity(groupId, identity.id);
        if (room != null) {
          logger.e('Rollback room $groupId due to error: $msg');
          await RoomService.instance.deleteRoom(room);
        }
        message.requestConfrim = RequestConfrimEnum.request;
        await MessageService.instance.updateMessageAndRefresh(message);
        EasyLoading.dismiss();
        if (msg.contains('Error creating StagedWelcome from Welcome')) {
          msg =
              'Your KeyPackage is invalid, Please contact the group admin, resend the invitation';
          await MlsGroupService.instance
              .uploadKeyPackages(identities: [identity], forceUpload: true);
          message.requestConfrim = RequestConfrimEnum.expired;
          await MessageService.instance.updateMessageAndRefresh(message);
        }
        await Get.dialog(CupertinoAlertDialog(
            title: const Text('Join Group Error'),
            content: Text(msg),
            actions: <Widget>[
              CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () async {
                    Get.back();
                    await MlsGroupService.instance.uploadKeyPackages(
                        identities: [identity], forceUpload: true);
                  })
            ]));
        return;
      }
      await Utils.offAndToNamedRoom(groupRoom);
      Get.find<HomeController>().loadIdentityRoomList(groupRoom.identityId);
    });
  }
}
