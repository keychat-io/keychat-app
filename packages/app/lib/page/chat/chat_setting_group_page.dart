import 'package:app/app.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/chat/message_bill/pay_to_relay_page.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:flutter/foundation.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:app/service/contact.service.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

import '../../controller/chat.controller.dart';
import '../../controller/home.controller.dart';
import '../components.dart';
import '../routes.dart';
import '../../service/group.service.dart';
import 'add_member_to_group.dart';

class GroupChatSettingPage extends StatefulWidget {
  final ChatController chatController;
  final Room room;
  const GroupChatSettingPage({
    required this.room,
    required this.chatController,
    super.key,
  });

  @override
  createState() => _GroupChatSettingPageState();
}

class _GroupChatSettingPageState extends State<GroupChatSettingPage> {
  GroupService groupService = GroupService.instance;
  RoomService roomService = RoomService.instance;
  HomeController homeController = Get.find<HomeController>();
  int gridCount = 5;
  late ChatController chatController;
  late Room room;
  late TextEditingController textEditingController;
  late TextEditingController userNameController;
  @override
  void initState() {
    super.initState();
    chatController = widget.chatController;
    room = widget.room;
    textEditingController =
        TextEditingController(text: chatController.roomObs.value.name);

    userNameController =
        TextEditingController(text: chatController.meMember.value.name);
  }

  @override
  void dispose() {
    textEditingController.dispose();
    userNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Obx(() => Text(
              "${chatController.roomObs.value.name ?? ""}(${chatController.enableMembers.length})")),
          actions: [
            IconButton(
                onPressed: () async {
                  List<RoomMember> members =
                      await chatController.room.getEnableMembers();
                  RoomMember? admin = await chatController.room.getAdmin();
                  Set<String> memberPubkeys = {};
                  for (RoomMember rm in members) {
                    memberPubkeys.add(rm.idPubkey);
                  }

                  // contacts
                  List<Contact> contactList = await ContactService.instance
                      .getListExcludeSelf(widget.room.identityId);
                  List<Map<String, dynamic>> contacts = [];
                  contactList = contactList.reversed.toList();
                  for (int i = 0; i < contactList.length; i++) {
                    var exist = false;
                    if (memberPubkeys.contains(contactList[i].pubkey)) {
                      exist = true;
                    }
                    contacts.add({
                      "pubkey": contactList[i].pubkey,
                      "npubkey": contactList[i].npubkey,
                      "name": contactList[i].displayName,
                      "exist": exist,
                      "isCheck": false,
                      "mlsPK": null,
                      "isAdmin":
                          (admin?.idPubkey ?? '') == contactList[i].pubkey
                    });
                  }
                  Get.to(() => AddMemberToGroup(
                        room: chatController.roomObs.value,
                        contacts: contacts,
                      ));
                },
                icon: const Icon(CupertinoIcons.plus_circle_fill))
          ],
        ),
        body: Obx(
          () => Column(
            children: [
              getImageGridView(chatController.enableMembers),
              Expanded(
                  child: SettingsList(
                platform: DevicePlatform.iOS,
                sections: [
                  generalSection(),
                  SettingsSection(tiles: [
                    RoomUtil.pinRoomSection(chatController),
                    if (!chatController.room.isSendAllGroup)
                      SettingsTile.switchTile(
                        title: const Text('Show Addresses'),
                        initialValue: chatController.showFromAndTo.value,
                        onToggle: (value) async {
                          chatController.showFromAndTo.toggle();
                          Get.back();
                        },
                        leading: const Icon(CupertinoIcons.mail),
                      ),
                    if (chatController.room.isShareKeyGroup ||
                        chatController.room.isKDFGroup ||
                        chatController.room.isMLSGroup)
                      RoomUtil.muteSection(chatController),
                  ]),
                  payToRelaySection(),
                  // receiveInPostOffice(),
                  dangerZoom(context)
                ],
              )),
            ],
          ),
        ));
  }

  receiveInPostOffice() {
    return SettingsSection(
      title: const Text('Message Relays'),
      tiles: [
        SettingsTile(
            leading: const Icon(CupertinoIcons.up_arrow),
            title: const Text('SendTo'),
            value: Flexible(
                child: Text(
                    chatController.roomObs.value.sendingRelays.isNotEmpty
                        ? chatController.roomObs.value.sendingRelays.join(',')
                        : 'All'))),
        SettingsTile(
            leading: const Icon(CupertinoIcons.down_arrow),
            title: const Text('ReceiveFrom'),
            value: Flexible(
                child: Text(
                    chatController.roomObs.value.receivingRelays.isNotEmpty
                        ? chatController.roomObs.value.receivingRelays.join(',')
                        : 'All'))),
      ],
    );
  }

  payToRelaySection() {
    return SettingsSection(
      tiles: [
        RoomUtil.mediaSection(chatController),
        SettingsTile.navigation(
          leading: const Icon(
            CupertinoIcons.bitcoin,
          ),
          title: const Text('Pay to Relay'),
          onPressed: (context) async {
            Get.to(() => PayToRelayPage(roomId: room.id));
          },
        ),
        // if (chatController.roomObs.value.type == RoomType.bot)
        //   SettingsTile.navigation(
        //     leading: const Icon(CupertinoIcons.bitcoin),
        //     title: const Text('Pay to Chat'),
        //     onPressed: (context) async {
        //       Get.to(() => PayToRelayPage(roomId: room.id));
        //     },
        //   ),
      ],
    );
  }

  Widget getImageGridView(List<RoomMember> list) {
    return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
            height: list.length < 10 ? 140 : 200,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridCount,
                childAspectRatio: 1.0,
              ),
              itemCount: list.length,
              itemBuilder: (context, index) {
                RoomMember rm = list[index];
                return InkWell(
                  key: Key(rm.idPubkey),
                  onTap: () async {
                    if (chatController.room.myIdPubkey == rm.idPubkey) {
                      EasyLoading.showToast('It \'s me');
                      return;
                    }
                    Contact? contact = await ContactService.instance.getContact(
                        chatController.room.identityId, rm.idPubkey);
                    String npub =
                        rust_nostr.getBech32PubkeyByHex(hex: rm.idPubkey);
                    contact ??= Contact(
                        pubkey: rm.idPubkey,
                        npubkey: npub,
                        identityId: chatController.room.identityId)
                      ..name = rm.name;
                    contact.name ??= rm.name;
                    Get.dialog(CupertinoAlertDialog(
                      title: Text(rm.name),
                      content: Container(
                        color: Colors.transparent,
                        child: Text(
                          npub,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      actions: <Widget>[
                        CupertinoDialogAction(
                          onPressed: () async {
                            Room? room = await RoomService.instance
                                .getRoomAndContainSession(contact!.pubkey,
                                    chatController.room.identityId);
                            if (room == null) {
                              await RoomService.instance.createRoomAndsendInvite(
                                  contact.pubkey,
                                  identity: chatController.room.getIdentity(),
                                  greeting:
                                      'From Group: ${chatController.roomObs.value.getRoomName()}');
                              return;
                            }

                            await Get.offAndToNamed('/room/${room.id}',
                                arguments: room);
                            await Get.find<HomeController>()
                                .loadIdentityRoomList(room.identityId);
                          },
                          child: const Text("Start Private Chat"),
                        ),
                        CupertinoDialogAction(
                          child: const Text("Copy Pubkey"),
                          onPressed: () {
                            String npub = rust_nostr.getBech32PubkeyByHex(
                                hex: rm.idPubkey);
                            Clipboard.setData(ClipboardData(text: npub));
                            EasyLoading.showToast('Copied');
                            Get.back();
                          },
                        ),
                        if (chatController.meMember.value.isAdmin)
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () {
                              Get.back();
                              Get.dialog(CupertinoAlertDialog(
                                title:
                                    Text("Are you sure to remove ${rm.name} ?"),
                                actions: <Widget>[
                                  CupertinoDialogAction(
                                    child: const Text("Cancel"),
                                    onPressed: () {
                                      Get.back();
                                    },
                                  ),
                                  CupertinoDialogAction(
                                    isDestructiveAction: true,
                                    child: const Text("Remove"),
                                    onPressed: () async {
                                      EasyLoading.show(status: 'Processing...');
                                      try {
                                        await groupService.removeMember(
                                            chatController.roomObs.value, rm);
                                        EasyLoading.dismiss();
                                        EasyLoading.showSuccess("Removed",
                                            duration:
                                                const Duration(seconds: 1));
                                      } catch (e, s) {
                                        logger.e(e.toString(),
                                            error: e, stackTrace: s);
                                        EasyLoading.showError(e.toString(),
                                            duration:
                                                const Duration(seconds: 2));
                                      } finally {
                                        Get.back();
                                      }
                                    },
                                  ),
                                ],
                              ));
                            },
                            child: const Text("Remove Member"),
                          ),
                        CupertinoDialogAction(
                          isDefaultAction: true,
                          onPressed: () {
                            Get.back();
                          },
                          child: const Text("Cancel"),
                        ),
                      ],
                    ));
                  },
                  child: Column(children: [
                    getRandomAvatar(rm.idPubkey, height: 40, width: 40),
                    Text(
                      rm.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                );
              },
            )));
  }

//sync key
  Widget reinviteGroup() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: InkWell(
            onTap: () async {
              var members = await chatController.roomObs.value.getMembers();
              Map<String, String> selectAccounts = {};
              for (RoomMember rm in members) {
                selectAccounts[rm.idPubkey] = rm.name;
              }
              await groupService.inviteToJoinGroup(
                  chatController.roomObs.value, selectAccounts);
              EasyLoading.showSuccess("Send invitation successfully");
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  margin:
                      const EdgeInsets.only(bottom: 15.0, top: 15, left: 12),
                  child: const Text(
                    "Reinvite",
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ),
                const Expanded(child: Text("")),
                Container(
                  margin:
                      const EdgeInsets.only(bottom: 15.0, top: 15, right: 8),
                  child: Text(
                    "",
                    style: TextStyle(fontSize: 20, color: Colors.grey.shade800),
                  ),
                ),
                Container(
                  margin:
                      const EdgeInsets.only(top: 15, bottom: 15.0, right: 10.0),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  generalSection() {
    String pubkey = chatController.roomObs.value.toMainPubkey;
    return SettingsSection(tiles: [
      SettingsTile(
          title: const Text("ID"),
          leading: const Icon(CupertinoIcons.person_3),
          value: textP(getPublicKeyDisplay(pubkey, 4)),
          onPressed: (context) {
            Clipboard.setData(ClipboardData(text: pubkey));
            EasyLoading.showToast('Copied');
          }),
      SettingsTile.navigation(
          leading: const Icon(CupertinoIcons.chart_bar),
          title: const Text('Mode'),
          value: Text(RoomUtil.getGroupModeName(
              chatController.roomObs.value.groupType)),
          onPressed: getGroupInfoBottomSheetWidget),
      chatController.meMember.value.isAdmin
          ? SettingsTile.navigation(
              title: const Text("Name"),
              leading: const Icon(CupertinoIcons.flag),
              value: Text("${chatController.roomObs.value.name}"),
              onPressed: (context) async {
                _showGroupNameDialog();
              })
          : SettingsTile(
              title: const Text("Group Name"),
              leading: const Icon(CupertinoIcons.flag),
              value: Text("${chatController.roomObs.value.name}")),
      if (chatController.meMember.value.isAdmin)
        SettingsTile.navigation(
            title: const Text("Update SharedKey"),
            leading: const Icon(Icons.refresh),
            onPressed: (context) async {
              await Get.dialog(CupertinoAlertDialog(
                title: const Text("Update SharedKey"),
                content: const Text(
                    "Regularly updating shared keys makes group chats more secure, and the receiving address will also be updated."),
                actions: <Widget>[
                  CupertinoDialogAction(
                    child: const Text("Cancel"),
                    onPressed: () {
                      Get.back();
                    },
                  ),
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    child: const Text("Confirm"),
                    onPressed: () async {
                      Get.back();
                      await MlsGroupService.instance
                          .adminUpdateKey(chatController.roomObs.value);
                      EasyLoading.showSuccess('Success');
                    },
                  ),
                ],
              ));
            }),
      SettingsTile.navigation(
        title: const Text("My Alias in Group"),
        leading: const Icon(CupertinoIcons.person),
        value: textP(chatController.meMember.value.name),
        onPressed: (context) async {
          if (chatController.room.isKDFGroup ||
              chatController.room.isShareKeyGroup) return;

          await Get.dialog(CupertinoAlertDialog(
            title: const Text("My Name"),
            content: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.only(top: 15),
              child: TextField(
                  controller: userNameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                      labelText: 'Name', border: OutlineInputBorder())),
            ),
            actions: <Widget>[
              CupertinoDialogAction(
                child: const Text("Cancel"),
                onPressed: () {
                  Get.back();
                },
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  String name = userNameController.text.trim();
                  if (name.isNotEmpty) {
                    await groupService.changeMyNickname(
                        chatController.roomObs.value, name);
                    await chatController.setMeMember(name);
                    chatController.meMember.refresh();
                    userNameController.clear();
                    chatController.resetMembers();
                    EasyLoading.showSuccess('Success');
                  }

                  Get.back();
                },
                child: const Text("Confirm"),
              ),
            ],
          ));
        },
      ),
      if (kDebugMode)
        SettingsTile.navigation(
          title: const Text("Not Invited Member"),
          leading: const Icon(CupertinoIcons.person),
          onPressed: (context) async {
            List<RoomMember> members = await room.getNotEnableMembers();
            List list = [];
            members.map((e) {
              list.add('${e.name} ${e.idPubkey} ${e.status.name}');
            });
            Get.dialog(
              CupertinoAlertDialog(
                title: const Text('Not enabled members'),
                content: SizedBox(
                  height: 300,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(list[index]),
                      );
                    },
                  ),
                ),
                actions: <Widget>[
                  CupertinoDialogAction(
                    child: const Text('Close'),
                    onPressed: () {
                      Get.back();
                    },
                  ),
                ],
              ),
            );
          },
        ),
    ]);
  }

  dangerZoom(BuildContext context) {
    return SettingsSection(tiles: [
      RoomUtil.autoCleanMessage(chatController),
      RoomUtil.clearHistory(chatController),
      SettingsTile(
          leading: const Icon(
            CupertinoIcons.trash,
            color: Colors.pink,
          ),
          title: Text(
              chatController.meMember.value.isAdmin
                  ? "Disband Group"
                  : "Leave Group",
              style: const TextStyle(color: Colors.pink)),
          onPressed: (context) {
            Get.dialog(_selfExitGroup(context));
          })
    ]);
  }

  void _showGroupNameDialog() async {
    await Get.dialog(CupertinoAlertDialog(
      title: const Text("Group Name"),
      content: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(top: 15),
        child: TextField(
          controller: textEditingController,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
              labelText: 'New Group Name', border: OutlineInputBorder()),
        ),
      ),
      actions: <Widget>[
        CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () {
              Get.back();
            }),
        CupertinoDialogAction(
          child: const Text("Confirm"),
          onPressed: () async {
            String newName = textEditingController.text;
            if (newName.isNotEmpty &&
                newName != chatController.roomObs.value.name) {
              await groupService.changeRoomName(
                  chatController.roomObs.value.id, newName);

              chatController.roomObs.value.name = newName;
              textEditingController.clear();
              chatController.roomObs.update((val) {});
              EasyLoading.showSuccess('Success');
            }
            Get.back();
          },
        ),
      ],
    ));
  }

  Widget _selfExitGroup(BuildContext context) {
    return CupertinoAlertDialog(
      title:
          Text(chatController.meMember.value.isAdmin ? "Disband?" : "Leave?"),
      content: Text(
          'Are you sure to ${chatController.meMember.value.isAdmin ? 'disband' : 'leave'} this group?'),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text('Cancel'),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(
                chatController.meMember.value.isAdmin ? "Disband" : "Leave"),
            onPressed: () async {
              EasyLoading.show(status: 'Loading...');
              try {
                chatController.meMember.value.isAdmin
                    ? await groupService
                        .dissolveGroup(chatController.roomObs.value)
                    : await groupService
                        .selfExitGroup(chatController.roomObs.value);
                EasyLoading.showSuccess('Success');
              } catch (e, s) {
                String msg = Utils.getErrorMessage(e);
                logger.e(msg, error: e, stackTrace: s);
                EasyLoading.showError(msg);
                return;
              }
              await Get.find<HomeController>()
                  .loadIdentityRoomList(room.identityId);
              Get.offAllNamed(Routes.root);
            }),
      ],
    );
  }
}
