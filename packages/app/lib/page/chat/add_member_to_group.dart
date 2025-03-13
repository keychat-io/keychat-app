import 'package:app/models/models.dart';
import 'package:app/page/components.dart';
import 'package:app/service/kdf_group.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/room.service.dart';
import 'package:flutter/cupertino.dart';

import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../service/group.service.dart';

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
  late TextEditingController _userNameController;
  final RefreshController _refreshController =
      RefreshController(initialRefresh: true);
  bool pageLoading = true;

  @override
  void initState() {
    super.initState();
    _userNameController = TextEditingController(text: "");
    _scrollController = ScrollController();
    _onLoading();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _scrollController.dispose();
    _refreshController.dispose();
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
    RoomMember? meMember = await widget.room.getMember(myPubkey);

    // only isSendAllGroup
    if (meMember != null && widget.room.isSendAllGroup) {
      if (!meMember.isAdmin) {
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
    }

    try {
      Room groupRoom =
          await RoomService.instance.getRoomByIdOrFail(widget.room.id);
      String sender = meMember == null ? myPubkey : meMember.name;
      if (widget.room.isMLSGroup) {
        await MlsGroupService.instance
            .sendWelcomeMessage(groupRoom, selectUsers, sender);
      } else if (widget.room.isKDFGroup) {
        await KdfGroupService.instance
            .inviteToJoinGroup(groupRoom, selectAccounts, sender);
      } else {
        await GroupService.instance
            .inviteToJoinGroup(groupRoom, selectAccounts);
      }
      EasyLoading.showSuccess('Success');
      Get.back();
    } catch (e, s) {
      EasyLoading.showError(e.toString());
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  void _onLoading() async {
    int currentLength = users.length;
    int nextLength = currentLength + 15;
    if (nextLength > widget.contacts.length) {
      nextLength = widget.contacts.length;
    }
    List<Map<String, dynamic>> news =
        widget.contacts.getRange(currentLength, nextLength).toList();
    if (news.isNotEmpty) {
      List<String> pubkeys = [];
      for (var u in news) {
        pubkeys.add(u['pubkey']);
      }
      Map res = await MlsGroupService.instance.getKeyPackagesFromRelay(pubkeys);

      for (var u in news) {
        String pubkey = u['pubkey'];
        if (res[pubkey] != null && res[pubkey].length > 0) {
          u['mlsPK'] = res[pubkey];
        }
      }
      users.addAll(news);
    }
    pageLoading = false;
    setState(() {});
    _refreshController.loadComplete();
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
          child: pageLoading
              ? pageLoadingSpinKit()
              : SmartRefresher(
                  enablePullDown: false,
                  enablePullUp: true,
                  header: const WaterDropHeader(),
                  controller: _refreshController,
                  onLoading: _onLoading,
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
                                    onChanged: widget.room.groupType ==
                                                GroupType.mls &&
                                            user['mlsPK'] == null
                                        ? null
                                        : (isCheck) {
                                            user['isCheck'] = isCheck!;
                                            setState(() {});
                                          })));
                      }))),
    );
  }
}
