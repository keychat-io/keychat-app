import 'package:app/service/kdf_group.service.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../controller/home.controller.dart';
import 'package:app/models/models.dart';
import '../common.dart';
import '../../service/contact.service.dart';
import '../../service/group.service.dart';

class AddGroupSelectMember extends StatefulWidget {
  final String groupName;
  final GroupType groupType;

  const AddGroupSelectMember(this.groupName, this.groupType, {super.key});

  @override
  _AddGroupSelectMemberState createState() => _AddGroupSelectMemberState();
}

class _AddGroupSelectMemberState extends State<AddGroupSelectMember>
    with TickerProviderStateMixin {
  GroupService groupService = GroupService();
  ContactService contactService = ContactService();
  HomeController hc = Get.find<HomeController>();

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _userNameController =
      TextEditingController(text: "");

  List<Contact> _contactList = [];

  final List<String> _tabs = ["Contacts", "Input"];
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {});
    super.initState();
    _getData();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  _getData() async {
    Identity identity = hc.getSelectedIdentity();
    List<Contact> contactList =
        await contactService.getListExcludeSelf(identity.id);

    setState(() {
      _contactList = contactList.reversed.toList();
    });
  }

  void _completeToCreatGroup() async {
    Map<String, String> selectAccounts = {};
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
      }
    }
    // from input, check public key
    if (_tabController.index == 1) {
      String input = _userNameController.text.trim();
      bool isCheck = nostrKeyInputCheck(input);
      if (!isCheck) return;
      String pubkey = rust_nostr.getHexPubkeyByBech32(bech32: input);
      selectAccounts[pubkey] = '';
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
      }
      Get.back();
    } catch (e, s) {
      logger.e('create room', error: e, stackTrace: s);
      EasyLoading.showError(e.toString());
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
          title: const Text(
            "Select Members",
          ),
          actions: [
            TextButton(
                onPressed: () => EasyThrottle.throttle('_completeToCreatGroup',
                    const Duration(seconds: 4), _completeToCreatGroup),
                child: const Text("Create Group"))
          ],
        ),
        body: SafeArea(
            child: Column(children: [
          TabBar(controller: _tabController, tabs: const <Widget>[
            Tab(
              child: Text("Contacts"),
            ),
            Tab(
              child: Text("Input"),
            ),
          ]),
          Expanded(
              child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              _fromContacts(),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 16.0),
                child: TextFormField(
                  controller: _userNameController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: 'Hex or npub...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          )),
        ])));
  }

  Widget _fromContacts() {
    return ListView.separated(
        itemCount: _contactList.length,
        controller: _scrollController,
        itemBuilder: (context, index) {
          return ListTile(
              dense: true,
              leading: getRandomAvatar(_contactList[index].pubkey,
                  height: 30, width: 30),
              title: Text(
                _contactList[index].displayName,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
              trailing: Checkbox(
                  value: _contactList[index].isCheck,
                  onChanged: (isCheck) {
                    _contactList[index].isCheck = isCheck!;
                    setState(() {});
                  }));
        },
        separatorBuilder: (BuildContext context, int index) {
          return Divider(
              color: Theme.of(context).dividerTheme.color?.withOpacity(0.03));
        });
  }
}
