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
import 'package:app/models/models.dart';

class CreateGroupSelectMember extends StatefulWidget {
  const CreateGroupSelectMember(
      this.groupName, this.relays, this.groupType, this.contacts,
      {super.key});
  final List<Map<String, dynamic>> contacts;
  final List<String> relays;
  final String groupName;
  final GroupType groupType;

  @override
  _CreateGroupSelectMemberState createState() =>
      _CreateGroupSelectMemberState();
}

class _CreateGroupSelectMemberState extends State<CreateGroupSelectMember>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _userNameController =
      TextEditingController(text: '');

  List<Map<String, dynamic>> users = [];

  bool pageLoading = true;

  @override
  void initState() {
    super.initState();
    _loading();
  }

  Future<void> _loading() async {
    if (widget.groupType == GroupType.sendAll) {
      setState(() {
        pageLoading = false;
        users = widget.contacts;
      });
      return;
    }
    final pubkeys = <String>[];
    for (var i = 0; i < widget.contacts.length; i++) {
      final contact = widget.contacts[i];
      if (contact['pubkey'] != null) {
        pubkeys.add(contact['pubkey']);
      }
    }
    final Map result =
        await MlsGroupService.instance.getKeyPackagesFromRelay(pubkeys);
    for (var i = 0; i < widget.contacts.length; i++) {
      final contact = widget.contacts[i];
      if (contact['pubkey'] != null) {
        final pubkey = contact['pubkey'] as String;
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
    super.dispose();
  }

  Future<void> _completeToCreatGroup() async {
    final selectAccounts = <String, String>{};
    final selectedContact = <Map<String, dynamic>>[];
    for (var i = 0; i < users.length; i++) {
      final Map contact = users[i];
      if (contact['isCheck'] == true) {
        var selectAccount = '';
        selectAccount = contact['pubkey'] as String;
        selectAccounts[selectAccount] = contact['name'] as String;
        selectedContact.add({
          'pubkey': contact['pubkey'],
          'name': contact['name'],
          'mlsPK': contact['mlsPK']
        });
      }
    }
    if (selectAccounts.isEmpty) {
      EasyLoading.showError('Please select at least one user');
      return;
    }
    final identity = Get.find<HomeController>().getSelectedIdentity();
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
      Get.find<HomeController>().loadIdentityRoomList(identity.id);
      Get.back();
      await Utils.offAndToNamedRoom(room);
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
      logger.e('create group error', error: e, stackTrace: s);
      EasyLoading.showError(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Select Members'),
        actions: [
          FilledButton(
              onPressed: () => EasyThrottle.throttle('_completeToCreatGroup',
                  const Duration(seconds: 4), _completeToCreatGroup),
              child: const Text('Done'))
        ],
      ),
      body: pageLoading
          ? pageLoadingSpinKit()
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (c, i) {
                final user = users[i];
                return ListTile(
                    dense: true,
                    leading: Utils.getRandomAvatar(user['pubkey']),
                    title: Text(user['name'], maxLines: 1),
                    subtitle:
                        Text(user['npubkey'], overflow: TextOverflow.ellipsis),
                    trailing: getAddMemeberCheckBox(widget.groupType, user));
              },
            ),
    );
  }

  Widget getAddMemeberCheckBox(GroupType groupType, Map<String, dynamic> user) {
    if (user['isAdmin'] == true || user['exist'] == true) {
      return const Checkbox(
          onChanged: null, value: true, activeColor: Colors.grey);
    }
    if (groupType == GroupType.sendAll) {
      return Checkbox(
          value: user['isCheck'],
          onChanged: (isCheck) {
            user['isCheck'] = isCheck;
            setState(() {});
          });
    }

    if (user['mlsPK'] == null) {
      return IconButton(
          onPressed: () {
            Get.dialog(CupertinoAlertDialog(
                title: const Text('Not upload MLS keys'),
                content: const Text(
                    'Notify your friend to restart the app, and the key will be uploaded automatically.'),
                actions: <Widget>[
                  CupertinoDialogAction(
                      onPressed: Get.back, child: const Text('OK'))
                ]));
          },
          icon: const Icon(Icons.warning, color: Colors.orange));
    }
    // user['mlsPK'] = snapshot.data;
    return Checkbox(
        value: user['isCheck'],
        onChanged: (isCheck) {
          user['isCheck'] = isCheck;
          setState(() {});
        });
    // });
  }
}
