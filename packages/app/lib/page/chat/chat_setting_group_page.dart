import 'package:app/app.dart';
// import 'package:app/page/chat/ForwardSelectRoom.dart';
import 'package:app/page/chat/RoomUtil.dart';
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
  final int? roomId;
  const ChatSettingGroupPage({super.key, this.roomId});

  @override
  createState() => _ChatSettingGroupPageState();
}

class _ChatSettingGroupPageState extends State<ChatSettingGroupPage> {
  HomeController homeController = Get.find<HomeController>();
  int gridCount = 5;
  late ChatController cc;
  late TextEditingController textEditingController;
  late TextEditingController userNameController;
  late String myAlias = '';
  bool isAdmin = false;
  @override
  void initState() {
    int roomId = widget.roomId ?? int.parse(Get.parameters['id']!);
    var controller = RoomService.getController(roomId);
    if (controller == null) {
      Get.back();
      return;
    }
    cc = controller;
    super.initState();
    RoomMember? myRoomMember =
        cc.getMemberByIdPubkey(cc.roomObs.value.myIdPubkey);
    myAlias = myRoomMember?.name ?? cc.roomObs.value.getIdentity().displayName;
    isAdmin = myRoomMember?.isAdmin ?? false;
    textEditingController = TextEditingController(text: cc.roomObs.value.name);
    userNameController = TextEditingController(text: myAlias);
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
              "${cc.roomObs.value.name ?? ""}(${cc.enableMembers.length})")),
          actions: [
            // if (cc.roomObs.value.isMLSGroup)
            //   IconButton(
            //       icon: const Icon(CupertinoIcons.share),
            //       onPressed: () async {
            //         String realMessage =
            //             'Share a Group: ${cc.roomObs.value.name}';
            //         List<Room>? forwardRooms = await Get.to(
            //             () => ForwardSelectRoom(realMessage,
            //                 cc.roomObs.value.getIdentity()),
            //             fullscreenDialog: true,
            //             transition: Transition.downToUp);
            //         if (forwardRooms == null || forwardRooms.isEmpty) return;
            //         await MlsGroupService.instance.shareToFriends(
            //             cc.roomObs.value,
            //             forwardRooms,
            //             realMessage);
            //         if (forwardRooms.length == 1) {
            //           Room forwardRoom = forwardRooms[0];
            //           if (forwardRoom.id != cc.roomObs.value.id) {
            //             await Get.toNamed('/room/${forwardRoom.id}',
            //                 arguments: forwardRoom);
            //           }
            //         }
            //       }),
            IconButton(
                onPressed: () async {
                  String? admin;
                  Set<String> memberPubkeys = {};
                  if (cc.roomObs.value.isMLSGroup) {
                    List<String> existedPubkeys =
                        await rust_mls.getGroupMembers(
                            nostrId:
                                cc.roomObs.value.getIdentity().secp256k1PKHex,
                            groupId: cc.roomObs.value.toMainPubkey);
                    memberPubkeys = Set.from(existedPubkeys);
                    admin = await cc.roomObs.value.getAdmin();
                  } else {
                    List<RoomMember> members =
                        await cc.roomObs.value.getActiveMembers();
                    admin = await cc.roomObs.value.getAdmin();
                    for (RoomMember rm in members) {
                      memberPubkeys.add(rm.idPubkey);
                    }
                  }
                  // contacts
                  List<Contact> contactList = await ContactService.instance
                      .getListExcludeSelf(cc.roomObs.value.identityId);
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
                      room: cc.roomObs.value, contacts: contacts));
                },
                icon: const Icon(CupertinoIcons.plus_circle_fill))
          ],
        ),
        body: Obx(
          () => Column(
            children: [
              getImageGridView(cc.members.values.toList()),
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
                                cc.roomObs.value.toMainPubkey, 4),
                            fontSize: 16),
                        onPressed: (context) {
                          Clipboard.setData(ClipboardData(
                              text: cc.roomObs.value.toMainPubkey));
                          EasyLoading.showToast('Copied');
                        }),
                    SettingsTile.navigation(
                        leading: const Icon(CupertinoIcons.chart_bar),
                        title: const Text('Mode'),
                        value: textP(RoomUtil.getGroupModeName(
                            cc.roomObs.value.groupType)),
                        onPressed: getGroupInfoBottomSheetWidget),
                    isAdmin
                        ? SettingsTile.navigation(
                            title: const Text("Group Name"),
                            leading: const Icon(CupertinoIcons.flag),
                            value: textP(
                                cc.roomObs.value.name ??
                                    cc.roomObs.value.toMainPubkey,
                                maxLength: 15),
                            onPressed: (context) async {
                              _showGroupNameDialog();
                            })
                        : SettingsTile(
                            title: const Text("Group Name"),
                            leading: const Icon(CupertinoIcons.flag),
                            value: textP(cc.roomObs.value.name ??
                                cc.roomObs.value.toMainPubkey)),
                    if (cc.roomObs.value.isMLSGroup)
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
                                        EasyLoading.show(
                                            status: 'Processing...');
                                        await MlsGroupService.instance
                                            .selfUpdateKey(cc.roomObs.value);
                                        EasyLoading.showSuccess('Success');
                                      } catch (e, s) {
                                        String msg = Utils.getErrorMessage(e);
                                        EasyLoading.showError(msg);
                                        logger.e(msg, error: e, stackTrace: s);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ));
                          }),
                    SettingsTile.navigation(
                      title: const Text("My Alias"),
                      leading: const Icon(CupertinoIcons.person),
                      value: textP(myAlias, maxLength: 15),
                      onPressed: (context) async {
                        if (cc.roomObs.value.isKDFGroup ||
                            cc.roomObs.value.isShareKeyGroup) {
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
                                try {
                                  String name = userNameController.text.trim();
                                  if (name.isEmpty) return;
                                  if (cc.roomObs.value.isSendAllGroup) {
                                    await GroupService.instance
                                        .changeMyNickname(
                                            cc.roomObs.value, name);
                                  } else if (cc.roomObs.value.isMLSGroup) {
                                    await MlsGroupService.instance
                                        .selfUpdateKey(cc.roomObs.value,
                                            extension: {'name': name});
                                  }
                                  setState(() {
                                    myAlias = name;
                                  });
                                  userNameController.clear();
                                  cc.resetMembers();
                                  EasyLoading.showSuccess('Success');
                                  Get.back();
                                } catch (e, s) {
                                  logger.e("Failed to update nickname",
                                      error: e, stackTrace: s);
                                  EasyLoading.showError(
                                      'Failed to update nickname: ${e.toString()}');
                                }
                              },
                              child: const Text("Confirm"),
                            ),
                          ],
                        ));
                      },
                    ),
                    if (cc.roomObs.value.isMLSGroup)
                      SettingsTile(
                          title: const Text("Relay"),
                          leading: const Icon(CupertinoIcons.globe),
                          value: textSmallGray(
                              context,
                              maxLines: 10,
                              cc.roomObs.value.sendingRelays.join('\n')),
                          onPressed: (context) {}),
                  ]),
                  SettingsSection(tiles: [
                    RoomUtil.pinRoomSection(cc),
                    if (!cc.roomObs.value.isSendAllGroup)
                      SettingsTile.switchTile(
                        title: const Text('Show Addresses'),
                        initialValue: cc.showFromAndTo.value,
                        onToggle: (value) async {
                          cc.showFromAndTo.toggle();
                          Get.back();
                        },
                        leading: const Icon(CupertinoIcons.mail),
                      ),
                    if (cc.roomObs.value.isShareKeyGroup ||
                        cc.roomObs.value.isKDFGroup ||
                        cc.roomObs.value.isMLSGroup)
                      RoomUtil.muteSection(cc),
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
                child: Text(cc.roomObs.value.sendingRelays.isNotEmpty
                    ? cc.roomObs.value.sendingRelays.join(',')
                    : 'All'))),
        SettingsTile(
            leading: const Icon(CupertinoIcons.down_arrow),
            title: const Text('ReceiveFrom'),
            value: Flexible(
                child: Text(cc.roomObs.value.receivingRelays.isNotEmpty
                    ? cc.roomObs.value.receivingRelays.join(',')
                    : 'All'))),
      ],
    );
  }

  payToRelaySection() {
    return SettingsSection(
      tiles: [
        RoomUtil.mediaSection(cc),
        SettingsTile.navigation(
          leading: const Icon(
            CupertinoIcons.bitcoin,
          ),
          title: const Text('Pay to Relay'),
          onPressed: (context) async {
            Get.toNamed(
                Routes.roomSettingPayToRelay
                    .replaceFirst(':id', cc.roomObs.value.id.toString()),
                id: GetPlatform.isDesktop ? GetXNestKey.room : null);
          },
        ),
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
        padding: const EdgeInsets.only(bottom: 4),
        child: SizedBox(
            height: list.length < 5 ? 100 : (list.length <= 10 ? 180 : 240),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridCount,
                childAspectRatio: 0.9,
              ),
              itemCount: list.length,
              itemBuilder: (context, index) {
                RoomMember rm = list[index];
                if (rm.name == rm.idPubkey) {
                  rm.status = UserStatusType.inviting;
                }
                return InkWell(
                  key: Key(rm.idPubkey),
                  onTap: () async {
                    if (cc.roomObs.value.myIdPubkey == rm.idPubkey) {
                      EasyLoading.showToast('It \'s me');
                      return;
                    }
                    Contact? contact = await ContactService.instance
                        .getContact(cc.roomObs.value.identityId, rm.idPubkey);
                    String npub =
                        rust_nostr.getBech32PubkeyByHex(hex: rm.idPubkey);
                    contact ??= Contact(
                        pubkey: rm.idPubkey,
                        npubkey: npub,
                        identityId: cc.roomObs.value.identityId)
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
                                    cc.roomObs.value.identityId);
                            if (room == null) {
                              await RoomService.instance.createRoomAndsendInvite(
                                  contact.pubkey,
                                  identity: cc.roomObs.value.getIdentity(),
                                  greeting:
                                      'From Group: ${cc.roomObs.value.getRoomName()}');
                              return;
                            }

                            await Utils.offAndToNamedRoom(room);
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
                        if (isAdmin)
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
                                      try {
                                        EasyLoading.show(
                                            status: 'Processing...');
                                        await GroupService.instance
                                            .removeMember(cc.roomObs.value, rm);
                                        EasyLoading.showSuccess("Removed",
                                            duration:
                                                const Duration(seconds: 1));
                                        Get.back();
                                      } catch (e, s) {
                                        logger.e(e.toString(),
                                            error: e, stackTrace: s);
                                        String msg = Utils.getErrorMessage(e);
                                        EasyLoading.showError(msg);
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
      RoomUtil.autoCleanMessage(cc),
      RoomUtil.clearHistory(cc),
      SettingsTile(
          leading: const Icon(
            CupertinoIcons.trash,
            color: Colors.pink,
          ),
          title: Text(isAdmin ? "Disband Group" : "Leave Group",
              style: const TextStyle(color: Colors.pink)),
          onPressed: _selfExitGroup)
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
          isDefaultAction: true,
          onPressed: () async {
            String newName = textEditingController.text;
            if (newName.isEmpty || newName == cc.roomObs.value.name) {
              EasyLoading.showToast('Please enter a new name');
              return;
            }

            try {
              EasyLoading.show(status: 'Processing...');

              await GroupService.instance
                  .changeRoomName(cc.roomObs.value.id, newName);

              cc.roomObs.value.name = newName;
              cc.roomObs.refresh();
              EasyLoading.showSuccess('Success');
              Get.find<HomeController>()
                  .loadIdentityRoomList(cc.roomObs.value.identityId);
              Get.back();
            } catch (e, s) {
              String msg = Utils.getErrorMessage(e);
              EasyLoading.showError(msg);
              logger.e(msg, error: e, stackTrace: s);
            }
          },
          child: const Text("Confirm"),
        ),
      ],
    ));
  }

  _selfExitGroup(BuildContext context) {
    Get.dialog(CupertinoAlertDialog(
      title: Text(isAdmin ? "Disband?" : "Leave?"),
      content:
          Text('Are you sure to ${isAdmin ? 'disband' : 'leave'} this group?'),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text('Cancel'),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(isAdmin ? "Disband" : "Leave"),
            onPressed: () async {
              EasyLoading.show(status: 'Loading...');
              try {
                isAdmin
                    ? await GroupService.instance
                        .dissolveGroup(cc.roomObs.value)
                    : await GroupService.instance
                        .selfExitGroup(cc.roomObs.value);
                EasyLoading.showSuccess('Success');
              } catch (e, s) {
                String msg = Utils.getErrorMessage(e);
                logger.e(msg, error: e, stackTrace: s);
                EasyLoading.showError(msg);
                return;
              }
              await Get.find<HomeController>()
                  .loadIdentityRoomList(cc.roomObs.value.identityId);
              Utils.offAllNamedRoom(Routes.root);
            }),
      ],
    ));
  }
}
