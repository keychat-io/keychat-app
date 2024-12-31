import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/chat/chat_settings_more.dart.dart';
import 'package:app/page/chat/message_bill/pay_to_relay_page.dart';
import 'package:app/page/components.dart';
import 'package:app/page/routes.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:settings_ui/settings_ui.dart';
import 'package:app/models/models.dart';
import '../../utils.dart';
import '../../service/room.service.dart';

// ignore: must_be_immutable
class ShowContactDetail extends StatefulWidget {
  Room room;
  ChatController chatController;

  ShowContactDetail(
      {super.key, required this.room, required this.chatController});

  @override
  State<StatefulWidget> createState() => _ShowContactDetailState();
}

class _ShowContactDetailState extends State<ShowContactDetail> {
  Relay? relay;

  _ShowContactDetailState();

  final TextEditingController _usernameController =
      TextEditingController(text: "");

  void cancelToast() {}

  @override
  void initState() {
    super.initState();
    RelayService.instance.getDefault().then((value) {
      setState(() {
        relay = value;
      });
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ChatController? chatController = RoomService.getController(widget.room.id);
    if (chatController == null) {
      return const Center(child: Text('Loading...'));
    }

    return Scaffold(
        appBar: AppBar(centerTitle: true, title: const Text('Chat Settings')),
        body: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
          Obx(() => Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                      leading: Utils.getRandomAvatar(
                          chatController.room.toMainPubkey,
                          height: 60,
                          width: 60),
                      title: Obx(() => Text(
                            chatController.roomObs.value.getRoomName(),
                            style: Theme.of(context).textTheme.titleMedium,
                          )),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((chatController.roomContact.value.name ?? '')
                              .isNotEmpty)
                            textSmallGray(context,
                                'Name: ${chatController.roomContact.value.name}'),
                          textSmallGray(context,
                              'ID: ${chatController.roomObs.value.npub}',
                              overflow: TextOverflow.visible)
                        ],
                      ),
                      trailing: IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                                text: chatController.roomObs.value.npub));
                            EasyLoading.showToast('Copied');
                          },
                          icon: const Icon(Icons.copy))),
                  if (chatController.roomObs.value.description != null)
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: textSmallGray(context,
                              chatController.roomObs.value.description!,
                              fontSize: 14, overflow: TextOverflow.clip),
                        )),
                ],
              ))),
          Expanded(
              child: Obx(
            () => SettingsList(platform: DevicePlatform.iOS, sections: [
              SettingsSection(tiles: [
                if (kDebugMode)
                  SettingsTile(
                    leading: const Icon(Icons.copy),
                    title: const Text("Hex ID Key"),
                    value: Text(getPublicKeyDisplay(
                        chatController.roomContact.value.pubkey, 6)),
                    onPressed: (context) {
                      Clipboard.setData(ClipboardData(
                          text: chatController.roomContact.value.pubkey));
                      EasyLoading.showSuccess("ID Key copied");
                    },
                  ),
                if (chatController.roomObs.value.type == RoomType.common)
                  SettingsTile.navigation(
                    title: const Text('Nickname'),
                    leading: const Icon(CupertinoIcons.pencil),
                    value: Text(chatController.roomContact.value.petname ?? ''),
                    onPressed: (context) async {
                      TextEditingController usernameController =
                          TextEditingController(
                              text: chatController.roomContact.value.petname);
                      await Get.dialog(CupertinoAlertDialog(
                        title: const Text("Nickname"),
                        content: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.only(top: 15),
                          child: TextField(
                              controller: usernameController,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (value) => handleUpdateName(
                                  chatController, usernameController),
                              decoration: const InputDecoration(
                                  labelText: 'Nickname',
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
                              await handleUpdateName(
                                  chatController, usernameController);
                            },
                            child: const Text("Confirm"),
                          ),
                        ],
                      ));
                    },
                  ),
                SettingsTile.navigation(
                  title: const Text('Security Settings'),
                  leading: const Icon(CupertinoIcons.lock_shield),
                  onPressed: (context) {
                    Get.to(() =>
                        ChatSettingsMoreDart(chatController: chatController));
                  },
                ),
                SettingsTile.switchTile(
                  title: const Text('Show Addresses'),
                  initialValue: chatController.showFromAndTo.value,
                  onToggle: (value) async {
                    chatController.showFromAndTo.toggle();
                    Get.back();
                  },
                  leading: const Icon(CupertinoIcons.mail),
                ),
                RoomUtil.pinRoomSection(chatController),
                if (chatController.roomObs.value.encryptMode ==
                        EncryptMode.signal &&
                    GetPlatform.isIOS)
                  RoomUtil.muteSection(chatController)
              ]),
              SettingsSection(tiles: [
                RoomUtil.mediaSection(chatController),
                SettingsTile.navigation(
                  leading: const Icon(
                    CupertinoIcons.bitcoin,
                  ),
                  title: const Text('Pay to Relay'),
                  onPressed: (context) async {
                    Get.to(() => PayToRelayPage(roomId: widget.room.id));
                  },
                ),
              ]),
              dangerZoom(),
            ]),
          ))
        ]));
  }

  dangerZoom() {
    return SettingsSection(
      tiles: [
        RoomUtil.autoCleanMessage(widget.chatController),
        RoomUtil.clearHistory(widget.chatController),
        SettingsTile(
          leading: const Icon(
            CupertinoIcons.trash,
            color: Colors.red,
          ),
          title: const Text('Delete Chat Room',
              style: TextStyle(color: Colors.red)),
          onPressed: (context) async {
            deleteChatRoomDialog(
                Get.context!, widget.chatController.roomObs.value);
          },
        ),
      ],
    );
  }

  void deleteChatRoomDialog(BuildContext buildContext, Room room) {
    Get.dialog(CupertinoAlertDialog(
      title: const Text("Delete Chat Room?"),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text(
            'Cancel',
          ),
          onPressed: () async {
            Get.back();
          },
        ),
        CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              try {
                await RoomService.instance
                    .deleteRoomHandler(room.toMainPubkey, room.identityId);
                Get.find<HomeController>()
                    .loadIdentityRoomList(room.identityId);
                await Get.offAllNamed(Routes.root);
              } catch (e) {
                String msg = Utils.getErrorMessage(e);
                logger.e(msg, error: e, stackTrace: StackTrace.current);
                EasyLoading.showError('Error: $msg');
              }
            }),
      ],
    ));
  }

  Future handleUpdateName(ChatController chatController,
      TextEditingController usernameController) async {
    if (usernameController.text.isEmpty) return;
    Contact contact0 = chatController.roomContact.value;
    contact0.petname = usernameController.text.trim();
    await ContactService.instance.saveContact(contact0);
    chatController.roomContact.value = contact0;
    chatController.roomContact.refresh();

    Get.back();
  }
}
