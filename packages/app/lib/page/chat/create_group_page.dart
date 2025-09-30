import 'package:app/controller/home.controller.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/chat/create_group_select_member.dart';
import 'package:app/page/setting/RelaySetting.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:app/models/models.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/group.service.dart';

class AddGroupPage extends StatefulWidget {
  const AddGroupPage({super.key});

  @override
  State<StatefulWidget> createState() => _AddGroupPageState();
}

class _AddGroupPageState extends State<AddGroupPage>
    with TickerProviderStateMixin {
  GroupService groupService = GroupService.instance;
  ContactService contactService = ContactService.instance;
  late TextEditingController _groupNameController;
  GroupType groupType = GroupType.mls;
  List<String> relays = [];
  late WebsocketService ws;
  late Identity identity;
  @override
  void initState() {
    _groupNameController = TextEditingController();
    identity = Get.find<HomeController>().getSelectedIdentity();
    super.initState();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('New Group Chat'),
        actions: [
          Utils.selectIdentityIconButton(identity, (Identity result) {
            identity = result;
          }),
        ],
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.miniCenterDocked,
      floatingActionButton: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        width: double.infinity,
        child: FilledButton(
          onPressed: () async {
            final groupName = _groupNameController.text.trim();
            if (groupName.isEmpty) {
              EasyLoading.showToast('Please input group name');
              return;
            }

            var contactList =
                await ContactService.instance.getFriendContacts(identity.id);
            contactList = contactList.reversed.toList();
            final list = <Map<String, dynamic>>[];
            for (var i = 0; i < contactList.length; i++) {
              final c = contactList[i];
              if (c.pubkey == identity.secp256k1PKHex) continue;
              const exist = false;
              list.add({
                'pubkey': c.pubkey,
                'npubkey': c.npubkey,
                'name': c.displayName,
                'contact': c,
                'exist': exist,
                'isCheck': false,
                'mlsPK': null,
                'isAdmin': false,
              });
            }
            var relays = <String>[];
            if (groupType == GroupType.mls) {
              final list = Get.find<WebsocketService>().getOnlineSocket();

              if (list.isEmpty) {
                Get.dialog(
                  CupertinoAlertDialog(
                    title: const Text('No relay available'),
                    content: const Text(
                      'Please reconnect the relay servers or add wss://relay.keychat.io',
                    ),
                    actions: <Widget>[
                      CupertinoDialogAction(
                        onPressed: Get.back,
                        child: const Text('Cancel'),
                      ),
                      CupertinoDialogAction(
                        child: const Text('Message Relay'),
                        onPressed: () async {
                          Get.back<void>();
                          await Get.to<void>(RelaySetting.new);
                        },
                      ),
                    ],
                  ),
                );
                return;
              }
              relays = list.map((e) => e.relay.url).toList();
            }

            await Get.bottomSheet<void>(
              CreateGroupSelectMember(
                groupName,
                Set<String>.from(relays).toList(),
                groupType,
                list,
                identity,
              ),
              isScrollControlled: true,
              ignoreSafeArea: false,
            );
          },
          child: const Text('Next'),
        ),
      ),
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SingleChildScrollView(
            child: RadioGroup<GroupType>(
              groupValue: groupType,
              onChanged: (value) {
                if (value == null) return;
                FocusScope.of(context).unfocus();
                setState(() {
                  groupType = value;
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextFormField(
                      controller: _groupNameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: Text(
                      'Select Group Mode',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ListTile(
                    title: Text(
                      'Large Group - MLS Protocol',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      RoomUtil.getGroupModeDescription(GroupType.mls),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    leading: const Radio<GroupType>(value: GroupType.mls),
                    selected: groupType == GroupType.mls,
                    selectedTileColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                  ),
                  ListTile(
                    selectedTileColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    title: Text(
                      'Small Group - Signal Protocol',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      RoomUtil.getGroupModeDescription(
                        GroupType.sendAll,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    selected: groupType == GroupType.sendAll,
                    leading: const Radio<GroupType>(value: GroupType.sendAll),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
