import 'package:app/app.dart';
import 'package:app/page/chat/ForwardSelectRoom.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/chat/message_bill/pay_to_relay_page.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:keychat_rust_ffi_plugin/api_mls.dart' as rust_mls;

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

class ChatSettingGroupPage extends StatefulWidget {
  const ChatSettingGroupPage({super.key});

  @override
  createState() => _ChatSettingGroupPageState();
}

class _ChatSettingGroupPageState extends State<ChatSettingGroupPage> {
  HomeController homeController = Get.find<HomeController>();
  int gridCount = 5;
  late ChatController chatController;
  late TextEditingController textEditingController;
  late TextEditingController userNameController;

  @override
  void initState() {
    int roomId = int.parse(Get.parameters['id']!);
    var controller = RoomService.getController(roomId);
    if (controller == null) {
      Get.back();
      return;
    }
    chatController = controller;
    super.initState();

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
            if (chatController.roomObs.value.isMLSGroup)
              IconButton(
                  icon: const Icon(CupertinoIcons.share),
                  onPressed: () async {
                    String realMessage =
                        'Share a Group: ${chatController.roomObs.value.name}';
                    List<Room>? forwardRooms = await Get.to(
                        () => ForwardSelectRoom(realMessage,
                            chatController.roomObs.value.getIdentity()),
                        fullscreenDialog: true,
                        transition: Transition.downToUp);
                    if (forwardRooms == null || forwardRooms.isEmpty) return;
                    await MlsGroupService.instance.shareToFriends(
                        chatController.roomObs.value,
                        forwardRooms,
                        realMessage);
                    if (forwardRooms.length == 1) {
                      Room forwardRoom = forwardRooms[0];
                      if (forwardRoom.id != chatController.roomObs.value.id) {
                        await Get.toNamed('/room/${forwardRoom.id}',
                            arguments: forwardRoom);
                      }
                    }
                  }),
            IconButton(
                onPressed: () async {
                  List<String> existedPubkeys = await rust_mls.getGroupMembers(
                      nostrId: chatController.roomObs.value
                          .getIdentity()
                          .secp256k1PKHex,
                      groupId: chatController.roomObs.value.toMainPubkey);
                  Set<String> memberPubkeys = Set.from(existedPubkeys);
                  String admin = await MlsGroupService.instance
                      .getAdmin(chatController.roomObs.value);
                  // contacts
                  List<Contact> contactList = await ContactService.instance
                      .getListExcludeSelf(chatController.room.identityId);
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
                      "isAdmin": admin == contactList[i].pubkey
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
              getImageGridView(chatController.members),
              Expanded(
                  child: SettingsList(
                platform: DevicePlatform.iOS,
                sections: [
                  SettingsSection(tiles: [
                    SettingsTile(
                        title: const Text("ID"),
                        leading: const Icon(CupertinoIcons.person_3),
                        value: textSmallGray(
                            context,
                            getPublicKeyDisplay(
                                chatController.roomObs.value.toMainPubkey, 4),
                            fontSize: 16),
                        onPressed: (context) {
                          Clipboard.setData(ClipboardData(
                              text: chatController.roomObs.value.toMainPubkey));
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
                            title: const Text("Group Name"),
                            leading: const Icon(CupertinoIcons.flag),
                            value: Text("${chatController.roomObs.value.name}"),
                            onPressed: (context) async {
                              _showGroupNameDialog();
                            })
                        : SettingsTile(
                            title: const Text("Group Name"),
                            leading: const Icon(CupertinoIcons.flag),
                            value: textSmallGray(
                                context, "${chatController.roomObs.value.name}",
                                fontSize: 16)),
                    if (chatController.room.isMLSGroup)
                      SettingsTile.navigation(
                          title: const Text("Update My Group Key"),
                          leading: const Icon(Icons.refresh),
                          onPressed: (context) async {
                            await Get.dialog(CupertinoAlertDialog(
                              title: const Text("Update My Group Key"),
                              content: const Text(
                                  "Regularly updating my group key makes chats more secure."),
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
                                    EasyThrottle.throttle('UpdateMyGroupKey',
                                        const Duration(seconds: 3), () async {
                                      try {
                                        await MlsGroupService.instance
                                            .selfUpdateKey(
                                                chatController.roomObs.value);
                                        EasyLoading.showSuccess('Success');
                                      } catch (e, s) {
                                        EasyLoading.showError(e.toString(),
                                            duration:
                                                const Duration(seconds: 3));
                                        logger.e(e.toString(),
                                            error: e, stackTrace: s);
                                      }
                                    });
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
                            chatController.room.isShareKeyGroup) {
                          return;
                        }

                        await Get.dialog(CupertinoAlertDialog(
                          title: const Text("My Name"),
                          content: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.only(top: 15),
                            child: TextField(
                                controller: userNameController,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                    labelText: 'Name',
                                    border: OutlineInputBorder())),
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
                                  await GroupService.instance.changeMyNickname(
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
                    )
                  ]),
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
            Get.to(
                () => PayToRelayPage(roomId: chatController.roomObs.value.id));
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
    list = list
        .where((e) =>
            e.status == UserStatusType.invited ||
            e.status == UserStatusType.inviting)
        .toList();
    return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
            height: list.length < 5 ? 80 : (list.length <= 10 ? 160 : 240),
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
                      content: Column(
                        children: [
                          if (rm.status == UserStatusType.inviting)
                            Text('Inviting',
                                style: Theme.of(Get.context!)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(color: Colors.amber.shade700)),
                          Text(npub),
                        ],
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
                                        await GroupService.instance
                                            .removeMember(
                                                chatController.roomObs.value,
                                                rm);
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
                    Utils.getRandomAvatar(rm.idPubkey, height: 40, width: 40),
                    Text(rm.name, overflow: TextOverflow.ellipsis),
                    if (rm.status == UserStatusType.inviting)
                      Text('Inviting',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.amber.shade700))
                  ]),
                );
              },
            )));
  }

  SettingsSection dangerZoom(BuildContext context) {
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
              await GroupService.instance
                  .changeRoomName(chatController.roomObs.value.id, newName);

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
                    ? await GroupService.instance
                        .dissolveGroup(chatController.roomObs.value)
                    : await GroupService.instance
                        .selfExitGroup(chatController.roomObs.value);
                EasyLoading.showSuccess('Success');
              } catch (e, s) {
                String msg = Utils.getErrorMessage(e);
                logger.e(msg, error: e, stackTrace: s);
                EasyLoading.showError(msg);
                return;
              }
              await Get.find<HomeController>().loadIdentityRoomList(
                  chatController.roomObs.value.identityId);
              Get.offAllNamed(Routes.root);
            }),
      ],
    );
  }
}
