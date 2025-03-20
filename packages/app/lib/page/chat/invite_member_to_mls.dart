import 'dart:convert' show jsonDecode;

import 'package:app/models/keychat/group_invitation_request_model.dart';
import 'package:app/models/models.dart';
import 'package:app/service/message.service.dart';

import 'package:app/service/mls_group.service.dart';
import 'package:app/service/room.service.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class InviteMemberToMLS extends StatefulWidget {
  final Room room;
  final List<Message> messages;
  const InviteMemberToMLS(this.room, this.messages, {super.key});

  @override
  State<StatefulWidget> createState() => _InviteMemberToMLSState();
}

class _InviteMemberToMLSState extends State<InviteMemberToMLS>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> users = [];
  Map<String, String> cachePKs = {};
  bool isLoading = false;
  _InviteMemberToMLSState();

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _onLoading();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _completeFromContacts() async {
    Map<String, String> selectAccounts = {};
    List<Map<String, dynamic>> selectUsers = [];
    List<Message> selectedMessages = [];
    for (int i = 0; i < users.length; i++) {
      Map<String, dynamic> contact = users[i];
      if (contact['isCheck']) {
        selectAccounts[contact['pubkey']] = contact['name'];
        selectUsers.add(contact);
        selectedMessages.add(contact['message']);
      }
    }

    if (selectAccounts.isEmpty) {
      EasyLoading.showError("Please select at least one user");
      return;
    }
    String myPubkey = widget.room.getIdentity().secp256k1PKHex;
    RoomMember? meMember = await widget.room.getMemberByIdPubkey(myPubkey);

    try {
      Room groupRoom =
          await RoomService.instance.getRoomByIdOrFail(widget.room.id);
      String sender = meMember == null ? myPubkey : meMember.name;

      await MlsGroupService.instance
          .addMemeberToGroup(groupRoom, selectUsers, sender);

      // update message status
      for (int i = 0; i < selectedMessages.length; i++) {
        selectedMessages[i].requestConfrim = RequestConfrimEnum.approved;
        await MessageService.instance
            .updateMessageAndRefresh(selectedMessages[i]);
      }
      EasyLoading.showSuccess('Success');
      Get.back();
    } catch (e, s) {
      EasyLoading.showError(e.toString());
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  void _onLoading() async {
    List<Map<String, dynamic>> contacts = [];
    for (int i = 0; i < widget.messages.length; i++) {
      try {
        Message message = widget.messages[i];
        var km = KeychatMessage.fromJson(jsonDecode(message.content));
        GroupInvitationRequestModel gir =
            GroupInvitationRequestModel.fromJson(jsonDecode(km.name!));
        String npub = rust_nostr.getBech32PubkeyByHex(hex: gir.myPubkey);
        contacts.add({
          "pubkey": gir.myPubkey,
          "npubkey": npub,
          "name": gir.myName,
          "exist": false,
          "isCheck": false,
          "mlsPK": gir.mlsPK,
          "isAdmin": false,
          "message": message
        });
      } catch (e, s) {
        logger.d(e.toString(), stackTrace: s);
      }
    }
    setState(() {
      users = contacts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          centerTitle: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.room.name ?? ''),
              Text(
                  style: Theme.of(context).textTheme.bodySmall,
                  "Request to Join Group")
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                EasyThrottle.throttle('_completeFromContacts',
                    const Duration(seconds: 2), _completeFromContacts);
              },
              child: const Text("Send Invite",
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            )
          ]),
      body: SafeArea(
          child: ListView.builder(
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
                    subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['npubkey'],
                              overflow: TextOverflow.ellipsis),
                          widget.room.groupType == GroupType.mls &&
                                  user['mlsPK'] == null
                              ? Text('Not upload MLS keys',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.pink))
                              : Container()
                        ]),
                    trailing: (user['isAdmin'] || user['exist']
                        ? const Icon(Icons.check_box,
                            color: Colors.grey, size: 30)
                        : Checkbox(
                            value: user['isCheck'],
                            onChanged: widget.room.groupType == GroupType.mls &&
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
