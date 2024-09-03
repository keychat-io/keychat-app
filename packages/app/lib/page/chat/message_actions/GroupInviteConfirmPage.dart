import 'package:app/models/models.dart';
import 'package:app/page/common.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/kdf_group.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class GroupInviteConfirmPage extends StatelessWidget {
  final Message message;
  final Room groupRoom;
  final int membersCount;
  final List<RoomMember> members;
  final Map<String, String> toJoinUserMap;

  const GroupInviteConfirmPage({
    super.key,
    required this.message,
    required this.groupRoom,
    required this.membersCount,
    required this.members,
    required this.toJoinUserMap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Invite New Members')),
        floatingActionButton: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  FilledButton(
                    onPressed: () async {
                      try {
                        if (groupRoom.isKDFGroup) {
                          Identity identity = groupRoom.getIdentity();
                          await KdfGroupService.instance.inviteToJoinGroup(
                              groupRoom, toJoinUserMap, identity.displayName);
                        } else {
                          await GroupService()
                              .inviteToJoinGroup(groupRoom, toJoinUserMap);
                        }
                        EasyLoading.showSuccess('Success');
                        message.requestConfrim = RequestConfrimEnum.approved;
                        MessageService().updateMessageAndRefresh(message);
                        Get.back();
                      } catch (e) {
                        EasyLoading.showError(e.toString());
                        logger.e(e.toString(), error: e);
                      }
                    },
                    child: const Text('Confirm'),
                  ),
                  FilledButton(
                    onPressed: () {
                      message.requestConfrim = RequestConfrimEnum.rejected;
                      MessageService().updateMessageAndRefresh(message);
                      Get.back();
                    },
                    style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(Colors.red)),
                    child: const Text('Reject',
                        style: TextStyle(color: Colors.white)),
                  )
                ])),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: SafeArea(
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  ListTile(
                    leading: getAvatarDot(groupRoom),
                    title: Text(
                        'Group: ${groupRoom.name ?? getPublicKeyDisplay(groupRoom.toMainPubkey)}'),
                    subtitle: Text(groupRoom.toMainPubkey),
                  ),
                  Row(
                    children: [
                      Text(
                        'Active Members: $membersCount',
                        style: Theme.of(context).textTheme.titleMedium,
                      )
                    ],
                  ),
                  Flexible(
                      flex: 1,
                      child: Card(
                          child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Wrap(
                                  direction: Axis.vertical,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    getRandomAvatar(members[index].idPubkey),
                                    Text(members[index].name)
                                  ]));
                        },
                      ))),
                  Row(
                    children: [
                      Text(
                        'New Members',
                        style: Theme.of(context).textTheme.titleMedium,
                      )
                    ],
                  ),
                  Flexible(
                      flex: 1,
                      child: ListView.builder(
                        itemCount: toJoinUserMap.keys.length,
                        itemBuilder: (context, index) {
                          String pubkey = toJoinUserMap.keys.elementAt(index);
                          bool existName =
                              (toJoinUserMap[pubkey]?.length ?? 0) > 0;
                          return ListTile(
                            leading: getRandomAvatar(pubkey),
                            title: existName
                                ? Text(toJoinUserMap[pubkey]!)
                                : Text(getPublicKeyDisplay(pubkey)),
                            subtitle: existName
                                ? Text(getPublicKeyDisplay(pubkey))
                                : null,
                          );
                        },
                      )),
                ]))));
  }
}
