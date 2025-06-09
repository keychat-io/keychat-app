import 'package:app/controller/home.controller.dart';
import 'package:app/page/components.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:app/models/models.dart';

class CreateGroupSelectMember extends StatefulWidget {
  final List<Map<String, dynamic>> contacts;
  final List<String> relays;
  final String groupName;
  final GroupType groupType;

  const CreateGroupSelectMember(
      this.groupName, this.relays, this.groupType, this.contacts,
      {super.key});

  @override
  _CreateGroupSelectMemberState createState() =>
      _CreateGroupSelectMemberState();
}

class _CreateGroupSelectMemberState extends State<CreateGroupSelectMember>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _userNameController =
      TextEditingController(text: "");

  List<Map<String, dynamic>> users = [];

  final RefreshController _refreshController =
      RefreshController(initialRefresh: true);
  bool pageLoading = true;

  @override
  void initState() {
    super.initState();
    _loading();
  }

  _loading() async {
    if (widget.groupType == GroupType.sendAll) {
      setState(() {
        pageLoading = false;
        users = widget.contacts;
      });
      return;
    }
    List<String> pubkeys = [];
    for (int i = 0; i < widget.contacts.length; i++) {
      Map<String, dynamic> contact = widget.contacts[i];
      if (contact['pubkey'] != null) {
        pubkeys.add(contact['pubkey']);
      }
    }
    Map result =
        await MlsGroupService.instance.getKeyPackagesFromRelay(pubkeys);
    for (int i = 0; i < widget.contacts.length; i++) {
      Map<String, dynamic> contact = widget.contacts[i];
      if (contact['pubkey'] != null) {
        String pubkey = contact['pubkey'];
        if (result[pubkey] != null) {
          contact['mlsPK'] = result[pubkey];
        }
      }
    }
    pageLoading = false;
    setState(() {
      users = widget.contacts;
    });
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _scrollController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _completeToCreatGroup() async {
    Map<String, String> selectAccounts = {};
    List<Map<String, dynamic>> selectedContact = [];
    for (int i = 0; i < users.length; i++) {
      Map contact = users[i];
      if (contact['isCheck']) {
        String selectAccount = "";
        selectAccount = contact['pubkey'];
        selectAccounts[selectAccount] = contact['name'];
        selectedContact.add({
          'pubkey': contact['pubkey'],
          'name': contact['name'],
          'mlsPK': contact['mlsPK']
        });
      }
    }
    if (selectAccounts.isEmpty) {
      EasyLoading.showError("Please select at least one user");
      return;
    }
    Identity identity = Get.find<HomeController>().getSelectedIdentity();
    try {
      late Room room;
      if (widget.groupType == GroupType.sendAll) {
        room = await GroupService.instance
            .createGroup(widget.groupName, identity, widget.groupType);
        await GroupService.instance.inviteToJoinGroup(room, selectAccounts);
      } else if (widget.groupType == GroupType.mls) {
        room = await MlsGroupService.instance.createGroup(
            widget.groupName, identity,
            toUsers: selectedContact, groupRelays: widget.relays);
      }
      await Get.find<HomeController>().loadIdentityRoomList(identity.id);
      Get.back();
      await Utils.offAndToNamedRoom(room);
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      logger.e('create group error', error: e, stackTrace: s);
      EasyLoading.showError(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Select Members"),
        actions: [
          FilledButton(
              onPressed: () => EasyThrottle.throttle('_completeToCreatGroup',
                  const Duration(seconds: 4), _completeToCreatGroup),
              child: const Text("Done"))
        ],
      ),
      body: pageLoading
          ? pageLoadingSpinKit(title: 'Loading...')
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (c, i) {
                Map<String, dynamic> user = users[i];
                return ListTile(
                    dense: true,
                    leading: Utils.getRandomAvatar(user['pubkey']),
                    title: Text(user['name'], maxLines: 1),
                    subtitle:
                        Text(user['npubkey'], overflow: TextOverflow.ellipsis),
                    trailing: getAddMemeberCheckBox(widget.groupType, user));
              },
            ),
    ));
  }

  Widget getAddMemeberCheckBox(GroupType groupType, Map<String, dynamic> user) {
    if (user['isAdmin'] || user['exist']) {
      return const Icon(Icons.check_box, color: Colors.grey, size: 30);
    }
    if (groupType == GroupType.sendAll) {
      return Checkbox(
          value: user['isCheck'],
          onChanged: (isCheck) {
            user['isCheck'] = isCheck!;
            setState(() {});
          });
    }

    // mls group
    // return FutureBuilder(future: () async {
    //   if (user['mlsPK'] != null) {
    //     return user['mlsPK'];
    //   }
    //   return MlsGroupService.instance.getKeyPackageFromRelay(user['pubkey']);
    // }(), builder: (context, snapshot) {
    //   if (snapshot.connectionState == ConnectionState.waiting) {
    //     return const CupertinoActivityIndicator();
    //   }
    if (user['mlsPK'] == null) {
      return IconButton(
          onPressed: () {
            Get.dialog(CupertinoAlertDialog(
                title: const Text('Not upload MLS keys'),
                content: const Text(
                    'Notify your friend to restart the app, and the key will be uploaded automatically.'),
                actions: <Widget>[
                  CupertinoDialogAction(
                      child: const Text('OK'),
                      onPressed: () {
                        Get.back();
                      })
                ]));
          },
          icon: const Icon(Icons.warning, color: Colors.orange));
    }
    // user['mlsPK'] = snapshot.data;
    return Checkbox(
        value: user['isCheck'],
        onChanged: (isCheck) {
          user['isCheck'] = isCheck!;
          setState(() {});
        });
    // });
  }
}
