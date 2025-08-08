import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/components.dart';
import 'package:app/page/routes.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:settings_ui/settings_ui.dart';
import 'package:app/models/models.dart';

// ignore: must_be_immutable
class ChatSettingContactPage extends StatefulWidget {
  final int? roomId;
  const ChatSettingContactPage({super.key, this.roomId});

  @override
  State<StatefulWidget> createState() => _ChatSettingContactPageState();
}

class _ChatSettingContactPageState extends State<ChatSettingContactPage> {
  Relay? relay;

  _ChatSettingContactPageState();

  final TextEditingController _usernameController =
      TextEditingController(text: "");
  late ChatController cc;

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
    return Scaffold(
        appBar: AppBar(centerTitle: true, title: const Text('Chat Settings')),
        body: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
          Obx(() => Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                      leading: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: Utils.getRandomAvatar(
                              cc.roomObs.value.toMainPubkey,
                              height: 60,
                              width: 60,
                              httpAvatar:
                                  cc.roomContact.value.avatarFromRelay)),
                      title: Obx(() => Text(
                            cc.roomObs.value.getRoomName(),
                            style: Theme.of(context).textTheme.titleMedium,
                          )),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((cc.roomContact.value.name ?? '').isNotEmpty)
                            textSmallGray(
                                context, 'Name: ${cc.roomContact.value.name}'),
                          textSmallGray(context, 'ID: ${cc.roomObs.value.npub}',
                              overflow: TextOverflow.visible),
                          if (cc.roomContact.value.displayAbout != null &&
                              cc.roomContact.value.displayAbout!.isNotEmpty)
                            Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: NoticeTextWidget.info(
                                    cc.roomContact.value.displayAbout ?? '',
                                    fontSize: 12,
                                    borderRadius: 8))
                        ],
                      ),
                      trailing: IconButton(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: cc.roomObs.value.npub));
                            EasyLoading.showToast('Copied');
                          },
                          icon: const Icon(Icons.copy))),
                  if (cc.roomObs.value.description != null)
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
                          child: textSmallGray(
                              context, cc.roomObs.value.description!,
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
                    value: Text(
                        getPublicKeyDisplay(cc.roomContact.value.pubkey, 6)),
                    onPressed: (context) {
                      Clipboard.setData(
                          ClipboardData(text: cc.roomContact.value.pubkey));
                      EasyLoading.showSuccess("ID Key copied");
                    },
                  ),
                if (cc.roomObs.value.type == RoomType.common)
                  SettingsTile.navigation(
                    title: const Text('Nickname'),
                    leading: const Icon(CupertinoIcons.pencil),
                    value: Text(cc.roomContact.value.petname ?? ''),
                    onPressed: (context) async {
                      TextEditingController usernameController =
                          TextEditingController(
                              text: cc.roomContact.value.petname);
                      await Get.dialog(CupertinoAlertDialog(
                        title: const Text("Nickname"),
                        content: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.only(top: 15),
                          child: TextField(
                              controller: usernameController,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (value) =>
                                  handleUpdateName(cc, usernameController),
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
                              await handleUpdateName(cc, usernameController);
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
                    Get.toNamed(
                        Routes.roomSettingContactSecurity.replaceFirst(
                            ':id', cc.roomObs.value.id.toString()),
                        id: GetPlatform.isDesktop ? GetXNestKey.room : null);
                  },
                ),
                SettingsTile.switchTile(
                  title: const Text('Show Addresses'),
                  initialValue: cc.showFromAndTo.value,
                  onToggle: (value) async {
                    cc.showFromAndTo.toggle();
                    Get.back();
                  },
                  leading: const Icon(CupertinoIcons.mail),
                ),
                RoomUtil.pinRoomSection(cc),
                if (cc.roomObs.value.encryptMode == EncryptMode.signal &&
                    GetPlatform.isIOS)
                  RoomUtil.muteSection(cc)
              ]),
              SettingsSection(tiles: [
                RoomUtil.mediaSection(cc),
                SettingsTile.navigation(
                  leading: const Icon(CupertinoIcons.bitcoin),
                  title: const Text('Pay to Relay'),
                  onPressed: (context) async {
                    Get.toNamed(
                        Routes.roomSettingPayToRelay.replaceFirst(
                            ':id', cc.roomObs.value.id.toString()),
                        id: GetPlatform.isDesktop ? GetXNestKey.room : null);
                  },
                ),
              ]),
              SettingsSection(
                tiles: [
                  RoomUtil.autoCleanMessage(cc),
                  RoomUtil.clearHistory(cc),
                  SettingsTile(
                    leading: const Icon(
                      CupertinoIcons.trash,
                      color: Colors.red,
                    ),
                    title: const Text('Delete Chat Room',
                        style: TextStyle(color: Colors.red)),
                    onPressed: (context) async {
                      deleteChatRoomDialog(Get.context!, cc.roomObs.value);
                    },
                  ),
                ],
              )
            ]),
          ))
        ]));
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
                Get.back();
                await RoomService.instance
                    .deleteRoomHandler(room.toMainPubkey, room.identityId);
                Get.find<HomeController>()
                    .loadIdentityRoomList(room.identityId);
                await Utils.offAllNamedRoom(Routes.root);
              } catch (e) {
                String msg = Utils.getErrorMessage(e);
                logger.e(msg, error: e, stackTrace: StackTrace.current);
                EasyLoading.showError('Error: $msg');
              }
            }),
      ],
    ));
  }

  Future handleUpdateName(
      ChatController cc, TextEditingController usernameController) async {
    if (usernameController.text.isEmpty) return;
    Contact contact0 = cc.roomContact.value;
    contact0.petname = usernameController.text.trim();
    await ContactService.instance.saveContact(contact0);
    cc.roomContact.value = contact0;
    cc.roomContact.refresh();

    Get.back();
  }
}
