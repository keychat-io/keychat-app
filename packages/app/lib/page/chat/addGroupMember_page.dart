import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
import 'package:app/service/kdf_group.service.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;

import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../service/contact.service.dart';
import '../../service/group.service.dart';

class AddGroupMember extends StatefulWidget {
  final Room room;
  final Set<String> members;
  const AddGroupMember({super.key, required this.room, required this.members});

  @override
  State<StatefulWidget> createState() => _AddGroupMemberState();
}

class _AddGroupMemberState extends State<AddGroupMember>
    with TickerProviderStateMixin {
  List<Contact> _contactList = [];
  bool isLoading = false;

  final List<String> _tabs = ["Select Members", "Input"];
  late TabController _tabController;

  _AddGroupMemberState();

  late ScrollController _scrollController;
  late TextEditingController _userNameController;

  @override
  void initState() {
    super.initState();
    _userNameController = TextEditingController(text: "");
    _scrollController = ScrollController();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {});
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
    List<Contact> contactList =
        await ContactService().getListExcludeSelf(widget.room.identityId);

    setState(() {
      _contactList = contactList;
    });
  }

  void _completeFromInput() async {
    EasyLoading.show(status: 'Proccessing');
    Map<String, String> selectAccounts = {};
    if (_userNameController.text.trim().length >= 63) {
      String hexPubkey = rustNostr.getHexPubkeyByBech32(
          bech32: _userNameController.text.trim());
      selectAccounts[hexPubkey] = '';
    }
    _sendInvite(selectAccounts);
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
    _sendInvite(selectAccounts);
  }

  Future _sendInvite(Map<String, String> selectAccounts) async {
    if (selectAccounts.isEmpty) {
      EasyLoading.showError('user not found or input error ');
      return;
    }
    try {
      if (widget.room.isKDFGroup) {
        await KdfGroupService.instance
            .inviteToJoinGroup(widget.room, selectAccounts);
      } else {
        await GroupService().inviteToJoinGroup(widget.room, selectAccounts);
      }
      EasyLoading.showSuccess('Success');
      Get.back();
    } catch (e) {
      EasyLoading.showError(e.toString());
      logger.e(e.toString(), error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Add Member"),
        actions: [
          TextButton(
            onPressed: () {
              var func = _tabController.index == 0
                  ? _completeFromContacts
                  : _completeFromInput;
              EasyThrottle.throttle(
                  '_completeFromContacts', const Duration(seconds: 2), func);
            },
            child: const Text(
              "Done",
            ),
          ),
        ],
        bottom: TabBar(controller: _tabController, tabs: const <Widget>[
          Tab(
            child: Text(
              "Select",
            ),
          ),
          Tab(
            child: Text(
              "Input",
            ),
          ),
        ]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _fromContacts(),
          _fromInput(),
        ],
      ),
    );
  }

  Widget _fromInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: TextField(
        controller: _userNameController,
        maxLines: null,
        decoration: const InputDecoration(
          labelText: 'Hex or npub...',
          hintStyle: TextStyle(fontSize: 18),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _fromContacts() {
    return ListView.builder(
        itemCount: _contactList.length,
        controller: _scrollController,
        itemBuilder: (context, index) {
          return ListTile(
              leading: getRandomAvatar(_contactList[index].pubkey,
                  height: 40, width: 40),
              title: Text(
                _contactList[index].displayName,
              ),
              subtitle: Text(
                _contactList[index].npubkey,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: widget.members.contains(_contactList[index].pubkey)
                  ? const Icon(Icons.check_box, color: Colors.grey, size: 30)
                  : Checkbox(
                      value: _contactList[index].isCheck,
                      onChanged: (isCheck) {
                        _contactList[index].isCheck = isCheck!;
                        setState(() {});
                      }));
        });
  }
}
