import 'package:app/models/models.dart';
import 'package:app/page/components.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/room.service.dart';
import 'package:flutter/cupertino.dart';

import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class AddMemberToGroup extends StatefulWidget {
  final Room room;
  final List<Map<String, dynamic>> contacts;
  const AddMemberToGroup(
      {super.key, required this.room, required this.contacts});

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
  late TextEditingController _pubkeyEditController;

  bool pageLoading = true;

  @override
  void initState() {
    super.initState();
    _pubkeyEditController = TextEditingController(text: "");
    _scrollController = ScrollController();
    _loading();
  }

  Future<void> _loading() async {
    if (widget.room.isSendAllGroup) {
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
    _pubkeyEditController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    bool isAdmin = await widget.room.checkAdminByIdPubkey(myPubkey);
    // only isSendAllGroup
    if (!isAdmin && widget.room.isSendAllGroup) {
      try {
        await GroupService.instance
            .sendInviteToAdmin(widget.room, selectAccounts);

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

    try {
      EasyLoading.show(status: 'Processing...');
      Room groupRoom =
          await RoomService.instance.getRoomByIdOrFail(widget.room.id);
      String sender = widget.room.getIdentity().displayName;
      if (widget.room.isMLSGroup) {
        await MlsGroupService.instance
            .addMemeberToGroup(groupRoom, selectUsers, sender);
      } else if (widget.room.isSendAllGroup) {
        await GroupService.instance
            .inviteToJoinGroup(groupRoom, selectAccounts);
      }
      EasyLoading.showSuccess('Success');
      Get.back();
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      EasyLoading.showError(msg);
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addMemberFromInput,
        child: const Icon(Icons.edit),
      ),
      body: SafeArea(
          child: pageLoading
              ? pageLoadingSpinKit()
              : ListView.builder(
                  itemCount: users.length,
                  controller: _scrollController,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> user = users[index];
                    return ListTile(
                        leading: Utils.getRandomAvatar(user['pubkey'],
                            height: 40, width: 40),
                        title: Text(user['name'],
                            style: Theme.of(context).textTheme.titleMedium),
                        dense: true,
                        subtitle: Text(user['npubkey'],
                            overflow: TextOverflow.ellipsis),
                        trailing:
                            getAddMemeberCheckBox(widget.room.groupType, user));
                  })),
    );
  }

  Widget getAddMemeberCheckBox(GroupType groupType, Map<String, dynamic> user) {
    if (user['isAdmin'] || user['exist']) {
      return Checkbox(onChanged: null, value: true, activeColor: Colors.grey);
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
                    'Notify your friend to restart the app, and the key will be uploaded automatically'),
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

  void _addMemberFromInput() {
    Get.dialog(CupertinoAlertDialog(
        title: const Text('Add Members'),
        content: TextField(
          controller: _pubkeyEditController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Npub or hex pubkey',
            border: OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste),
              onPressed: () async {
                final clipboardData = await Clipboard.getData('text/plain');
                if (clipboardData?.text != null) {
                  _pubkeyEditController.text = clipboardData!.text!;
                }
              },
            ),
          ),
        ),
        actions: <Widget>[
          CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                _pubkeyEditController.clear();
                Get.back();
              }),
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                try {
                  String input = _pubkeyEditController.text.trim();
                  // input is a hex string, decode in json
                  if (!(input.length == 64 || input.length == 63)) {
                    EasyLoading.showError(
                        'Please input a valid npub or hex pubkey');
                    return;
                  }
                  String hexPubkey = input;
                  if (input.startsWith('npub') && input.length == 63) {
                    hexPubkey = rust_nostr.getHexPubkeyByBech32(bech32: input);
                  }
                  // Check if hexPubkey already exists in users
                  var alreadyExists = users
                      .firstWhereOrNull((user) => user['pubkey'] == hexPubkey);
                  if (alreadyExists != null) {
                    if (alreadyExists['exist']) {
                      EasyLoading.showError('User already exists in the group');
                      return;
                    }
                    alreadyExists['isCheck'] = true;
                    setState(() {});
                    Get.back();
                    // EasyLoading.showError('User already exists in the list');
                    return;
                  }
                  EasyLoading.show(status: 'Loading...');
                  Map result = await MlsGroupService.instance
                      .getKeyPackagesFromRelay([hexPubkey]);
                  String? mlsPK = result[hexPubkey];
                  if (mlsPK == null) {
                    EasyLoading.dismiss();
                    EasyLoading.showError(
                        'The user has not uploaded their MLS key');
                    return;
                  }
                  var map = {
                    "pubkey": hexPubkey,
                    "npubkey": rust_nostr.getBech32PubkeyByHex(hex: hexPubkey),
                    "name": input.substring(0, 6),
                    "exist": false,
                    "isCheck": true,
                    "mlsPK": result[hexPubkey],
                    "isAdmin": false
                  };
                  users.add(map);
                  setState(() {});
                  _pubkeyEditController.clear();
                  EasyLoading.dismiss();
                  EasyLoading.showSuccess('User added successfully');
                  Get.back();
                } catch (e, s) {
                  String msg = Utils.getErrorMessage(e);
                  logger.e(msg, error: e, stackTrace: s);
                  EasyLoading.showError(msg);
                }
              },
              child: const Text('Add'))
        ]));
  }
}
