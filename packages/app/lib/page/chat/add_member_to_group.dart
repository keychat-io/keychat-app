import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
import 'package:app/service/kdf_group.service.dart';
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
  List<Contact> _contactList = [];
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

    setState(() {
      _contactList = contactList.reversed.toList();
    });
  }

  void _completeFromContacts() async {
    EasyLoading.show(status: 'Proccessing');
    String myPubkey =
        Get.find<HomeController>().getSelectedIdentity().secp256k1PKHex;
    Map<String, String> selectAccounts = {};
    for (int i = 0; i < _contactList.length; i++) {
      Contact contact = _contactList[i];
      if (contact.isCheck) {
        String selectAccount = "";
        if (myPubkey == contact.pubkey) {
          selectAccount = myPubkey;
        } else {
          selectAccount = contact.pubkey;
        }
        selectAccounts[selectAccount] = contact.displayName;
      }
    }
    _sendInvite(myPubkey, selectAccounts);
  }

  Future _sendInvite(
      String myPubkey, Map<String, String> selectAccounts) async {
    if (selectAccounts.isEmpty) {
      EasyLoading.showError("Please select at least one user");
      return;
    }
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
      if (widget.room.isKDFGroup) {
        String sender = meMember == null ? myPubkey : meMember.name;
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
          AppBar(centerTitle: true, title: const Text("Add Member"), actions: [
        FilledButton(
            onPressed: () {
              EasyThrottle.throttle('_completeFromContacts',
                  const Duration(seconds: 2), _completeFromContacts);
            },
            child: const Text("Done"))
      ]),
      body: SafeArea(
          child: ListView.builder(
              itemCount: _contactList.length,
              controller: _scrollController,
              itemBuilder: (context, index) {
                return ListTile(
                    leading: getRandomAvatar(_contactList[index].pubkey,
                        height: 40, width: 40),
                    title: Text(_contactList[index].displayName),
                    dense: true,
                    subtitle: Text(_contactList[index].npubkey,
                        overflow: TextOverflow.ellipsis),
                    trailing: widget.adminPubkey == _contactList[index].pubkey
                        ? const Icon(Icons.check_box,
                            color: Colors.grey, size: 30)
                        : Checkbox(
                            value: _contactList[index].isCheck,
                            onChanged: (isCheck) {
                              _contactList[index].isCheck = isCheck!;
                              setState(() {});
                            }));
              })),
    );
  }
}
