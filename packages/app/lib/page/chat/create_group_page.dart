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
import '../../service/contact.service.dart';
import '../../service/group.service.dart';

class AddGroupPage extends StatefulWidget {
  const AddGroupPage({super.key});

  @override
  State<StatefulWidget> createState() => _AddGroupPageState();
}

class _AddGroupPageState extends State<AddGroupPage>
    with TickerProviderStateMixin {
  GroupService groupService = GroupService.instance;
  ContactService contactService = ContactService.instance;
  GroupType selectedGroupType = GroupType.mls;
  late TextEditingController _groupNameController;
  GroupType groupType = GroupType.mls;
  List<String> relays = [];
  late WebsocketService ws;
  Identity identity = Get.find<HomeController>().getSelectedIdentity();
  @override
  void initState() {
    _groupNameController = TextEditingController();
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
          leading: GestureDetector(
              onTap: () {
                Get.back();
              },
              child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_ios),
                      Utils.getRandomAvatar(identity.secp256k1PKHex,
                          httpAvatar: identity.avatarFromRelay,
                          height: 22,
                          width: 22)
                    ],
                  ))),
          centerTitle: true,
          title: const Text("New Group Chat"),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.miniCenterDocked,
        floatingActionButton: Container(
            constraints: BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            width: double.infinity,
            child: FilledButton(
                onPressed: () async {
                  String groupName = _groupNameController.text.trim();
                  if (groupName.isEmpty) {
                    EasyLoading.showToast('Please input group name');
                    return;
                  }

                  Identity identity =
                      Get.find<HomeController>().getSelectedIdentity();
                  List<Contact> contactList = await ContactService.instance
                      .getListExcludeSelf(identity.id);
                  contactList = contactList.reversed.toList();
                  List<Map<String, dynamic>> list = [];
                  for (int i = 0; i < contactList.length; i++) {
                    var exist = false;
                    list.add({
                      "pubkey": contactList[i].pubkey,
                      "npubkey": contactList[i].npubkey,
                      "name": contactList[i].displayName,
                      "exist": exist,
                      "isCheck": false,
                      "mlsPK": null,
                      "isAdmin": false
                    });
                  }
                  List<String> relays = [];
                  if (groupType == GroupType.mls) {
                    var list = Get.find<WebsocketService>().getOnlineSocket();

                    if (list.isEmpty) {
                      Get.dialog(
                        CupertinoAlertDialog(
                          title: const Text('No relay available'),
                          content: const Text(
                              'Please reconnect the relay servers or add wss://relay.keychat.io'),
                          actions: <Widget>[
                            CupertinoDialogAction(
                              child: const Text('Cancel'),
                              onPressed: () {
                                Get.back();
                              },
                            ),
                            CupertinoDialogAction(
                              child: const Text('Message Relay'),
                              onPressed: () {
                                Get.back();
                                Get.to(() => RelaySetting());
                              },
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                    relays = list.map((e) => e.relay.url).toList();
                  }

                  Get.bottomSheet(
                      CreateGroupSelectMember(
                          groupName, relays, groupType, list),
                      isScrollControlled: true,
                      ignoreSafeArea: false);
                },
                child: const Text('Next'))),
        body: SafeArea(
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
              child: SingleChildScrollView(
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
                        )),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: Text("Select Group Mode",
                            style: Theme.of(context).textTheme.titleMedium)),
                    ListTile(
                        title: Text("Large Group - MLS Protocol",
                            style: Theme.of(context).textTheme.titleSmall),
                        subtitle: Text(
                            RoomUtil.getGroupModeDescription(GroupType.mls),
                            style: Theme.of(context).textTheme.bodySmall),
                        leading: Radio<GroupType>(
                          value: GroupType.mls,
                          groupValue: groupType,
                          onChanged: (value) {
                            FocusScope.of(context).unfocus();
                            setState(() {
                              groupType = value as GroupType;
                              selectedGroupType = GroupType.mls;
                            });
                          },
                        ),
                        selected: selectedGroupType == GroupType.mls,
                        selectedTileColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1)),
                    ListTile(
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      title: Text('Small Group - Signal Protocol',
                          style: Theme.of(context).textTheme.titleSmall),
                      subtitle: Text(
                          RoomUtil.getGroupModeDescription(GroupType.sendAll),
                          style: Theme.of(context).textTheme.bodySmall),
                      selected: selectedGroupType == GroupType.sendAll,
                      leading: Radio<GroupType>(
                        value: GroupType.sendAll,
                        groupValue: groupType,
                        onChanged: (value) {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            groupType = value as GroupType;
                            selectedGroupType = GroupType.sendAll;
                          });
                        },
                      ),
                    ),
                  ]))),
        ));
  }
}
