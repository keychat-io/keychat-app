import 'package:app/controller/chat.controller.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/chat/chat_settings_more.dart.dart';
import 'package:app/page/chat/message_bill/pay_to_relay_page.dart';
import 'package:app/page/components.dart';
import 'package:app/page/routes.dart';
import 'package:app/service/relay.service.dart';
import 'package:flutter/cupertino.dart';
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
  Contact contact;
  Room room;
  ChatController chatController;

  ShowContactDetail(
      {super.key,
      required this.contact,
      required this.room,
      required this.chatController});

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
    RelayService().getDefault().then((value) {
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
                      onTap: () {
                        if (chatController
                            .roomContact.value.pubkey.isNotEmpty) {
                          Get.toNamed(Routes.contact,
                              arguments: chatController.roomContact.value);
                        }
                      },
                      leading: getRandomAvatar(chatController.room.toMainPubkey,
                          height: 60, width: 60),
                      title: Text(
                        chatController.roomObs.value.getRoomName(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(getPublicKeyDisplay(
                          chatController.roomObs.value.npub)),
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
                if (chatController.roomObs.value.type != RoomType.bot)
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
            child: const Text(
              'Delete',
            ),
            onPressed: () async {
              RoomService()
                  .deleteRoomHandler(room.toMainPubkey, room.identityId);
            }),
      ],
    ));
  }
}
