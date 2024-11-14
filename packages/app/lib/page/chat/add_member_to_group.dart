import 'package:app/models/models.dart';
import 'package:app/service/kdf_group.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/room.service.dart';
import 'package:flutter/cupertino.dart';

import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../service/contact.service.dart';
import '../../service/group.service.dart';

class AddMemberToGroup extends StatefulWidget {
  final Room room;
  final Set<String> members;
  final String adminPubkey;
  const AddMemberToGroup(
      {super.key,
      required this.room,
      required this.members,
      required this.adminPubkey});

  @override
  State<StatefulWidget> createState() => _AddMemberToGroupState();
}

class _AddMemberToGroupState extends State<AddMemberToGroup>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> users = [];
  Map<String, String> cachePKs = {};
  bool isLoading = false;

  _AddMemberToGroupState();

  late ScrollController _scrollController;
  late TextEditingController _userNameController;

  @override
  void initState() {
    super.initState();
    _userNameController = TextEditingController(text: "");
    _scrollController = ScrollController();

    _getData();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _getData() async {
    List<Contact> contactList =
        await ContactService().getListExcludeSelf(widget.room.identityId);
    List<Map<String, dynamic>> list = [];
    contactList = contactList.reversed.toList();
    for (int i = 0; i < contactList.length; i++) {
      var exist = false;
      if (widget.members.contains(contactList[i].pubkey)) {
        exist = true;
      }
      list.add({
        "pubkey": contactList[i].pubkey,
        "npubkey": contactList[i].npubkey,
        "name": contactList[i].displayName,
        "exist": exist,
        "isCheck": false,
        "mlsPK": null,
        "mlsPKLoaded": false,
        "isAdmin": widget.adminPubkey == contactList[i].pubkey
      });
    }

    setState(() {
      users = list;
    });
  }

  void _completeFromContacts() async {
    Map<String, String> selectAccounts = {};
    List<Map<String, dynamic>> selectUsers = [];
    for (int i = 0; i < users.length; i++) {
      Map<String, dynamic> contact = users[i];
      if (contact['isCheck']) {
        selectAccounts[contact['pubkey']] = contact['name'];
        selectUsers.add(contact);
      }
    }

    if (selectAccounts.isEmpty) {
      EasyLoading.showError("Please select at least one user");
      return;
    }
    String myPubkey = widget.room.getIdentity().secp256k1PKHex;
    RoomMember? meMember = await widget.room.getMember(myPubkey);
    if (meMember != null) {
      if (!meMember.isAdmin) {
        try {
          await GroupService().sendInviteToAdmin(widget.room, selectAccounts);

          EasyLoading.dismiss();
          Get.dialog(CupertinoAlertDialog(
              title: const Text('Success'),
              content: const Text('The invitation has been sent to the admin'),
              actions: <Widget>[
                CupertinoDialogAction(
                    child: const Text('OK'),
                    onPressed: () {
                      Get.back();
                      Get.back();
                    })
              ]));
        } catch (e, s) {
          logger.e(e.toString(), error: e, stackTrace: s);
          EasyLoading.showError(e.toString());
        }
        return;
      }
    }

    try {
      Room groupRoom = await RoomService().getRoomByIdOrFail(widget.room.id);
      String sender = meMember == null ? myPubkey : meMember.name;
      if (widget.room.isMLSGroup) {
        await MlsGroupService.instance
            .inviteToJoinGroup(groupRoom, selectUsers, sender);
      } else if (widget.room.isKDFGroup) {
        await KdfGroupService.instance
            .inviteToJoinGroup(groupRoom, selectAccounts, sender);
      } else {
        await GroupService().inviteToJoinGroup(groupRoom, selectAccounts);
      }
      EasyLoading.showSuccess('Success');
      Get.back();
    } catch (e, s) {
      EasyLoading.showError(e.toString());
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(centerTitle: true, title: const Text("Add Members"), actions: [
        FilledButton(
            onPressed: () {
              EasyThrottle.throttle('_completeFromContacts',
                  const Duration(seconds: 2), _completeFromContacts);
            },
            child: const Text("Done"))
      ]),
      body: SafeArea(
          child: ListView.builder(
              itemCount: users.length,
              controller: _scrollController,
              itemBuilder: (context, index) {
                Map<String, dynamic> user = users[index];
                return ListTile(
                    leading:
                        getRandomAvatar(user['pubkey'], height: 40, width: 40),
                    title: Text(user['name'],
                        style: Theme.of(context).textTheme.titleMedium),
                    dense: true,
                    subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['npubkey'],
                              overflow: TextOverflow.ellipsis),
                          FutureBuilder(future: () async {
                            if (widget.room.groupType != GroupType.mls) {
                              return null;
                            }
                            if (user['mlsPK'] != null) return user['mlsPK'];
                            if (user['mlsPKLoaded']) return user['mlsPK'];
                            if (user['isAdmin']) return null;
                            if (user['exist']) return null;

                            String? pk = await MlsGroupService.instance
                                .getPK(user['pubkey']);
                            user['mlsPKLoaded'] = true;
                            user['mlsPK'] = pk;
                            setState(() {});
                            return pk;
                          }(), builder: (context, snapshot) {
                            if (user['isAdmin']) return Container();
                            if (user['exist']) return Container();

                            if (widget.room.groupType == GroupType.mls &&
                                snapshot.data == null) {
                              return Text('Not upload MLS keys',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.pink));
                            }
                            return Container();
                          })
                        ]),
                    trailing: widget.room.groupType == GroupType.mls &&
                            user['mlsPKLoaded'] == false &&
                            !user['isAdmin'] &&
                            !user['exist']
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : (user['isAdmin'] || user['exist']
                            ? const Icon(Icons.check_box,
                                color: Colors.grey, size: 30)
                            : Checkbox(
                                value: user['isCheck'],
                                tristate:
                                    widget.room.groupType == GroupType.mls &&
                                        user['mlsPK'] == null,
                                onChanged:
                                    widget.room.groupType == GroupType.mls &&
                                            user['mlsPK'] == null
                                        ? null
                                        : (isCheck) {
                                            user['isCheck'] = isCheck!;
                                            setState(() {});
                                          })));
              })),
    );
  }
}
