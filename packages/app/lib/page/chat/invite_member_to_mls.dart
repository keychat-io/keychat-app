import 'dart:convert' show jsonDecode;

import 'package:keychat/models/models.dart';
import 'package:keychat/service/message.service.dart';

import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:keychat/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class InviteMemberToMLS extends StatefulWidget {
  const InviteMemberToMLS(this.room, this.messages, {super.key});
  final Room room;
  final List<Message> messages;

  @override
  State<StatefulWidget> createState() => _InviteMemberToMLSState();
}

class _InviteMemberToMLSState extends State<InviteMemberToMLS>
    with TickerProviderStateMixin {
  _InviteMemberToMLSState();
  List<Map<String, dynamic>> users = [];
  Map<String, String> cachePKs = {};
  bool isLoading = false;

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

  Future<void> _completeFromContacts() async {
    final selectAccounts = <String, String>{};
    final selectUsers = <Map<String, dynamic>>[];
    final selectedMessages = <Message>[];
    for (var i = 0; i < users.length; i++) {
      final contact = users[i];
      if (contact['isCheck'] == true) {
        selectAccounts[contact['pubkey']] = contact['name'] as String;
        selectUsers.add(contact);
        selectedMessages.add(contact['message']);
      }
    }

    if (selectAccounts.isEmpty) {
      EasyLoading.showError('Please select at least one user');
      return;
    }

    try {
      final groupRoom = await RoomService.instance.getRoomByIdOrFail(
        widget.room.id,
      );
      final sender = widget.room.getIdentity().displayName;

      await MlsGroupService.instance.addMemeberToGroup(
        groupRoom,
        selectUsers,
        sender,
      );

      // update message status
      for (var i = 0; i < selectedMessages.length; i++) {
        selectedMessages[i].requestConfrim = RequestConfrimEnum.approved;
        await MessageService.instance.updateMessageAndRefresh(
          selectedMessages[i],
        );
      }
      EasyLoading.showSuccess('Success');
      Get.back<void>();
    } catch (e, s) {
      EasyLoading.showError(e.toString());
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  Future<void> _onLoading() async {
    final contacts = <Map<String, dynamic>>[];
    for (var i = 0; i < widget.messages.length; i++) {
      try {
        final message = widget.messages[i];
        final km = KeychatMessage.fromJson(jsonDecode(message.content));
        final gir = GroupInvitationRequestModel.fromJson(jsonDecode(km.name!));
        final npub = rust_nostr.getBech32PubkeyByHex(hex: gir.myPubkey);
        contacts.add({
          'pubkey': gir.myPubkey,
          'npubkey': npub,
          'name': gir.myName,
          'exist': false,
          'isCheck': false,
          'mlsPK': gir.mlsPK,
          'isAdmin': false,
          'message': message,
        });
      } catch (e, s) {
        logger.i(e.toString(), stackTrace: s);
      }
    }
    setState(() {
      users = contacts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.room.name ?? ''),
              Text(
                style: Theme.of(context).textTheme.bodySmall,
                'Request to Join Group',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                EasyThrottle.throttle(
                  '_completeFromContacts',
                  const Duration(seconds: 2),
                  _completeFromContacts,
                );
              },
              child: const Text(
                'Send Invite',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        body: ListView.builder(
          itemCount: users.length,
          controller: _scrollController,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: Utils.getRandomAvatar(user['pubkey']),
              title: Text(
                user['name'],
                style: Theme.of(context).textTheme.titleMedium,
              ),
              dense: true,
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['npubkey'], overflow: TextOverflow.ellipsis),
                  if (widget.room.groupType == GroupType.mls &&
                      user['mlsPK'] == null)
                    Text(
                      'Not upload MLS keys',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.pink),
                    )
                  else
                    Container(),
                ],
              ),
              trailing: (user['isAdmin'] == true || user['exist'] == true
                  ? const Icon(Icons.check_box, color: Colors.grey, size: 30)
                  : Checkbox(
                      value: user['isCheck'],
                      onChanged:
                          widget.room.groupType == GroupType.mls &&
                              user['mlsPK'] == null
                          ? null
                          : (isCheck) {
                              user['isCheck'] = isCheck;
                              setState(() {});
                            },
                    )),
            );
          },
        ),
      ),
    );
  }
}
