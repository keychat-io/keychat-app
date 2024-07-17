import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/chat/chat_settings_more.dart.dart';
import 'package:app/page/chat/message_bill/message_bill_page.dart';
import 'package:app/page/routes.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rustSignal;

import 'package:app/service/chatx.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Chat Settings'),
        ),
        body: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
          Obx(() => Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  onTap: () => Get.toNamed(Routes.contact,
                      arguments: chatController.roomContact.value),
                  leading: getRandomAvatar(chatController.room.toMainPubkey,
                      height: 60, width: 60),
                  title: Text(chatController.roomContact.value.displayName),
                  subtitle: Text(getPublicKeyDisplay(
                      chatController.roomContact.value.npubkey)),
                  trailing: IconButton(
                      onPressed: () {
                        Get.toNamed(Routes.contact,
                            arguments: chatController.roomContact.value);
                      },
                      icon: const Icon(CupertinoIcons.right_chevron)),
                ),
              )),
          Expanded(
              child: Obx(
            () => SettingsList(platform: DevicePlatform.iOS, sections: [
              SettingsSection(tiles: [
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
                  title: const Text('Ecash Bills'),
                  onPressed: (context) async {
                    Get.to(() => MessageBillPage(roomId: widget.room.id));
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
              try {
                EasyLoading.show(status: 'Loading...');
                await RoomService().deleteRoom(room);
                final remoteAddress = rustSignal.KeychatProtocolAddress(
                    name: room.toMainPubkey, deviceId: room.identityId);
                Identity? identity =
                    await IdentityService().getIdentityById(room.identityId);
                if (identity == null) return;
                final keyPair = Get.find<ChatxService>().getKeyPair(identity);
                // delete signal session
                await rustSignal.deleteSession(
                    keyPair: keyPair, address: remoteAddress);
                EasyLoading.showSuccess('Successfully');
                await Get.find<HomeController>()
                    .loadIdentityRoomList(room.identityId);
                Get.offAllNamed(Routes.root);
              } catch (e, s) {
                logger.e('delete faild', error: e, stackTrace: s);
                EasyLoading.showError(e.toString());
              } finally {
                EasyLoading.dismiss();
              }
            }),
      ],
    ));
  }
}
