import 'package:app/models/room_member.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/components.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class GroupInfoWidget extends StatelessWidget {
  final NostrEventModel subEvent;
  final String idPubkey;
  final String groupId;
  const GroupInfoWidget(this.subEvent, this.idPubkey, this.groupId,
      {super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
          leading:
              IconButton(icon: const Icon(Icons.close), onPressed: Get.back),
          title: Text('New Group Invitation')),
      body: Column(
        children: [
          Expanded(
              child: SettingsList(
            platform: DevicePlatform.iOS,
            sections: [
              SettingsSection(tiles: [
                SettingsTile(
                  title: const Text("ID"),
                  value: textP(getPublicKeyDisplay(groupId)),
                ),
                SettingsTile(
                    title: const Text('Mode'), value: Text('MLS Large Group')),
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
    ));
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
                      Utils.getRandomAvatar(rm.idPubkey, height: 40, width: 40),
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
