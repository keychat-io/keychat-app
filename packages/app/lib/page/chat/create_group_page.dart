import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/chat/addGroupSelectMember.dart';
import 'package:app/service/websocket.service.dart';
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
  GroupService groupService = GroupService();
  ContactService contactService = ContactService();

  late TextEditingController _groupNameController;
  GroupType groupType = GroupType.kdf;
  List<String> relays = [];
  late WebsocketService ws;
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
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            "New Group Chat",
          ),
        ),
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
                      padding: const EdgeInsets.only(left: 16, top: 16),
                      child: Text(
                        "Select Group Mode",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ListTile(
                      title: Text(
                        "KDF Mode",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        RoomUtil.getGroupModeDescription(GroupType.shareKey),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      leading: Radio<GroupType>(
                        value: GroupType.kdf,
                        groupValue: groupType,
                        onChanged: (value) {
                          setState(() {
                            groupType = value as GroupType;
                          });
                        },
                      ),
                    ),
                    ListTile(
                      title: Text(
                        'Pairwise Mode',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        RoomUtil.getGroupModeDescription(GroupType.sendAll),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      leading: Radio<GroupType>(
                        value: GroupType.sendAll,
                        groupValue: groupType,
                        onChanged: (value) {
                          setState(() {
                            groupType = value as GroupType;
                          });
                        },
                      ),
                    ),
                    // Visibility(
                    //   visible: groupType == GroupType.shareKey,
                    //   child: Container(
                    //     padding: const EdgeInsets.only(left: 16, top: 16),
                    //     child: Text(
                    //       "Group Relay",
                    //       style: Theme.of(context).textTheme.titleMedium,
                    //     ),
                    //   ),
                    // ),
                    // Visibility(
                    //   visible: groupType == GroupType.shareKey,
                    //   child: relays.isEmpty
                    //       ? const Text('No any connected relay')
                    //       : ListView.builder(
                    //           shrinkWrap: true,
                    //           physics: const NeverScrollableScrollPhysics(),
                    //           itemCount: relays.length,
                    //           itemBuilder: (context, index) {
                    //             return RadioListTile<int>(
                    //               title: Text(relays[index]),
                    //               value: index,
                    //               dense: true,
                    //               groupValue: _selectedRelay,
                    //               subtitle: Text(
                    //                   'Fee: ${_getRelayFee(relays[index])} sat/message'),
                    //               onChanged: (int? value) {
                    //                 if (value == null) return;

                    //                 setState(() {
                    //                   _selectedRelay = value;
                    //                 });
                    //               },
                    //             );
                    //           },
                    //         ),
                    // ),
                    Container(
                        padding:
                            const EdgeInsets.only(left: 16, right: 16, top: 30),
                        child: FilledButton(
                            style: ButtonStyle(
                                minimumSize: WidgetStateProperty.all(
                                    const Size(double.infinity, 44))),
                            onPressed: () {
                              String groupName =
                                  _groupNameController.text.trim();
                              if (groupName.isEmpty) {
                                EasyLoading.showToast(
                                    'Please input group name');
                                return;
                              }

                              Get.to(() =>
                                  AddGroupSelectMember(groupName, groupType));
                            },
                            child: const Text(
                              'Next',
                            ))),
                  ]))),
        ));
  }
}
