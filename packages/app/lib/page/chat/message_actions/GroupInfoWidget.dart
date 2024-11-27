import 'package:app/models/keychat/room_profile.dart';
import 'package:app/models/room_member.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/components.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class GroupInfoWidget extends StatelessWidget {
  final RoomProfile roomProfile;
  final String idPubkey;
  const GroupInfoWidget(this.roomProfile, this.idPubkey, {super.key});

  @override
  Widget build(BuildContext context) {
    List<RoomMember> members = [];
    for (var user in roomProfile.users) {
      user['roomId'] = 0;
      RoomMember rm = RoomMember.fromJson(user);
      if (rm.status == UserStatusType.invited ||
          rm.status == UserStatusType.inviting) {
        members.add(rm);
      }
    }
    return Scaffold(
      appBar: AppBar(
          leading:
              IconButton(icon: const Icon(Icons.close), onPressed: Get.back),
          title: Text('Group: ${roomProfile.name}')),
      body: Column(
        children: [
          getImageGridView(members),
          Expanded(
              child: SettingsList(
            platform: DevicePlatform.iOS,
            sections: [
              SettingsSection(tiles: [
                SettingsTile(
                  title: const Text("ID"),
                  value: textP(getPublicKeyDisplay(roomProfile.pubkey)),
                ),
                SettingsTile(
                    title: const Text('Mode'),
                    value:
                        Text(RoomUtil.getGroupModeName(roomProfile.groupType))),
                SettingsTile(
                    title: const Text("Members Count"),
                    value: Text(members.length.toString())),
              ])
            ],
          )),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    FilledButton(
                        onPressed: () {
                          Get.back(result: false);
                        },
                        style: ButtonStyle(
                          foregroundColor:
                              WidgetStateProperty.all<Color>(Colors.white70),
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.pressed)) {
                                return Theme.of(context).colorScheme.primary;
                              } else {
                                return Colors.red;
                              }
                            },
                          ),
                        ),
                        child: const Text('Reject',
                            style: TextStyle(color: Colors.white))),
                    FilledButton(
                        onPressed: () {
                          Get.back(result: true);
                        },
                        child: const Text('Join Group')),
                  ]))
        ],
      ),
    );
  }

  Widget getImageGridView(List<RoomMember> list) {
    return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
            height: list.length < 5 ? 100 : (list.length <= 10 ? 200 : 300),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, childAspectRatio: 1.0),
              itemCount: list.length,
              itemBuilder: (context, index) {
                RoomMember rm = list[index];

                return InkWell(
                    key: Key(rm.idPubkey),
                    child: Column(children: [
                      getRandomAvatar(rm.idPubkey, height: 40, width: 40),
                      Text(rm.name, overflow: TextOverflow.ellipsis),
                      if (rm.status == UserStatusType.inviting)
                        Text('Inviting',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: Colors.amber.shade700))
                    ]));
              },
            )));
  }
}
