import 'package:app/controller/home.controller.dart';
import 'package:app/page/components.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
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
  void initState() {
    super.initState();
    _onLoading();
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
    late Room room;
    Identity identity = Get.find<HomeController>().getSelectedIdentity();
    try {
      if (widget.groupType == GroupType.sendAll) {
        room = await GroupService.instance
            .createGroup(widget.groupName, identity, widget.groupType);
        await GroupService.instance.inviteToJoinGroup(room, selectAccounts);
      } else if (widget.groupType == GroupType.mls) {
        room = await MlsGroupService.instance.createGroup(
            widget.groupName, identity,
            toUsers: selectedContact, groupRelays: widget.relays);
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
              child: const Text("Done"))
        ],
      ),
      body: pageLoading
          ? pageLoadingSpinKit(title: 'Loading contact\'s mls KeyPackages')
          : SmartRefresher(
              enablePullDown: false,
              enablePullUp: true,
              header: const WaterDropHeader(),
              controller: _refreshController,
              onLoading: _onLoading,
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (c, i) {
                  Map user = users[i];
                  return ListTile(
                      dense: true,
                      leading: Utils.getRandomAvatar(user['pubkey']),
                      title: Text(user['name'], maxLines: 1),
                      subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['npubkey'],
                                overflow: TextOverflow.ellipsis),
                            widget.groupType == GroupType.mls &&
                                    user['mlsPK'] == null
                                ? Text('Not upload MLS keys',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.pink))
                                : Container()
                          ]),
                      trailing: widget.groupType == GroupType.mls &&
                              user['mlsPK'] == null
                          ? IconButton(
                              onPressed: () {
                                EasyLoading.showToast('Getting key packages');
                                MlsGroupService.instance
                                    .getKeyPackagesFromRelay(
                                        [user['pubkey']]).then((res) {
                                  if (res[user['pubkey']] == null) {
                                    EasyLoading.showError(
                                        'Not found his mls key package');
                                    return;
                                  }
                                  user['mlsPK'] = res[user['pubkey']];
                                  setState(() {});
                                  EasyLoading.showError('Refreshed');
                                });
                              },
                              icon: Icon(Icons.refresh))
                          : Checkbox(
                              value: user['isCheck'],
                              onChanged: (isCheck) {
                                user['isCheck'] = isCheck!;
                                setState(() {});
                              }));
                },
              ),
            ),
    );
  }
}
