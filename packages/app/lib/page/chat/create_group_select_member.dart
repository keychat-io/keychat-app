import 'package:app/service/kdf_group.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../controller/home.controller.dart';
import 'package:app/models/models.dart';
import '../../service/contact.service.dart';
import '../../service/group.service.dart';

class CreateGroupSelectMember extends StatefulWidget {
  final String groupName;
  final GroupType groupType;

  const CreateGroupSelectMember(this.groupName, this.groupType, {super.key});

  @override
  _CreateGroupSelectMemberState createState() =>
      _CreateGroupSelectMemberState();
}

class _CreateGroupSelectMemberState extends State<CreateGroupSelectMember>
    with TickerProviderStateMixin {
  HomeController hc = Get.find<HomeController>();

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _userNameController =
      TextEditingController(text: "");

  List<Contact> _contactList = [];

  @override
  void initState() {
    super.initState();
    _getData();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _getData() async {
    Identity identity = hc.getSelectedIdentity();
    List<Contact> contactList =
        await ContactService().getListExcludeSelf(identity.id);
    if (widget.groupType == GroupType.mls) {
      for (var contact in contactList) {
        String? pk = await MlsGroupService.instance.getPK(contact.pubkey);
        contact.mlsPK = pk;
      }
    }
    setState(() {
      _contactList = contactList.toList();
    });
  }

  void _completeToCreatGroup() async {
    Map<String, String> selectAccounts = {};
    List<Map<String, dynamic>> selectedContact = [];
    for (int i = 0; i < _contactList.length; i++) {
      Contact contact = _contactList[i];
      if (contact.isCheck) {
        String selectAccount = "";
        if (hc.getSelectedIdentity().secp256k1PKHex == contact.pubkey) {
          selectAccount = hc.getSelectedIdentity().secp256k1PKHex;
        } else {
          selectAccount = contact.pubkey;
        }
        selectAccounts[selectAccount] = contact.displayName;
        selectedContact.add({
          'pubkey': contact.pubkey,
          'displayName': contact.displayName,
          'pk': contact.mlsPK
        });
      }
    }
    if (selectAccounts.isEmpty) {
      EasyLoading.showError("Please select at least one user");
      return;
    }
    late Room room;
    Identity identity = hc.getSelectedIdentity();
    try {
      if (widget.groupType == GroupType.sendAll) {
        room = await GroupService()
            .createGroup(widget.groupName, identity, widget.groupType);
        await GroupService().inviteToJoinGroup(room, selectAccounts);
      } else if (widget.groupType == GroupType.kdf) {
        room = await KdfGroupService.instance
            .createGroup(widget.groupName, identity, selectAccounts);
      } else if (widget.groupType == GroupType.mls) {
        room = await MlsGroupService.instance
            .createGroup(widget.groupName, identity, selectedContact);
      }
      Get.back();
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      logger.e('create group error', error: e, stackTrace: s);
      EasyLoading.showError(msg);
      return;
    }

    await Get.offAndToNamed('/room/${room.id}', arguments: room);
    await Get.find<HomeController>().loadIdentityRoomList(room.identityId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text("Select Members"),
          actions: [
            FilledButton(
                onPressed: () => EasyThrottle.throttle('_completeToCreatGroup',
                    const Duration(seconds: 4), _completeToCreatGroup),
                child: const Text("Create Group"))
          ],
        ),
        body: SafeArea(
            child: ListView.builder(
          itemCount: _contactList.length,
          controller: _scrollController,
          itemBuilder: (context, index) {
            Contact contact = _contactList[index];
            return ListTile(
                dense: true,
                leading: getRandomAvatar(contact.pubkey, height: 30, width: 30),
                title: Text(contact.displayName, maxLines: 1),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.npubkey,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (contact.mlsPK == null)
                      Text(
                        'Not upload MLS keys',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.pink),
                      )
                  ],
                ),
                trailing: Checkbox(
                    value: contact.isCheck,
                    tristate: contact.mlsPK == null,
                    onChanged: contact.mlsPK == null
                        ? null
                        : (isCheck) {
                            contact.isCheck = isCheck!;
                            setState(() {});
                          }));
          },
        )));
  }
}
