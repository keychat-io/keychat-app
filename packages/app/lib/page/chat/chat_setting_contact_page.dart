import 'package:keychat/controller/chat.controller.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/page/chat/search_messages_page.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/page/routes.dart';
import 'package:keychat/page/widgets/notice_text_widget.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:settings_ui/settings_ui.dart';

class ChatSettingContactPage extends StatefulWidget {
  const ChatSettingContactPage({super.key, this.roomId});
  final int? roomId;

  @override
  State<StatefulWidget> createState() => _ChatSettingContactPageState();
}

class _ChatSettingContactPageState extends State<ChatSettingContactPage> {
  _ChatSettingContactPageState();
  Relay? relay;

  final TextEditingController _usernameController = TextEditingController(
    text: '',
  );
  late ChatController cc;

  @override
  void initState() {
    final roomId = widget.roomId ?? int.parse(Get.parameters['id']!);
    final controller = RoomService.getController(roomId);
    if (controller == null) {
      Get.back<void>();
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
      body: Column(
        children: [
          Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      radius: 25,
                      child: Utils.getRandomAvatar(
                        cc.roomObs.value.toMainPubkey,
                        size: 60,
                        contact: cc.roomContact.value,
                      ),
                    ),
                    title: Obx(
                      () => Text(
                        cc.roomObs.value.getRoomName(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        textSmallGray(
                          context,
                          'ID: ${cc.roomObs.value.npub}',
                        ),
                        if (cc.roomContact.value.petname !=
                                cc.roomContact.value.name &&
                            cc.roomContact.value.name != null)
                          textSmallGray(
                            context,
                            'Name: ${cc.roomContact.value.name ?? ''}',
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: cc.roomObs.value.npub),
                        );
                        EasyLoading.showToast('Copied');
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ),
                  if (cc.roomContact.value.displayAbout != null &&
                      cc.roomContact.value.displayAbout!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: NoticeTextWidget.info(
                        cc.roomContact.value.displayAbout ?? '',
                        fontSize: 12,
                        borderRadius: 8,
                      ),
                    ),
                  if (cc.roomObs.value.description != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: textSmallGray(
                          context,
                          cc.roomObs.value.description!,
                          fontSize: 14,
                          overflow: TextOverflow.clip,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => SettingsList(
                platform: DevicePlatform.iOS,
                sections: [
                  SettingsSection(
                    tiles: [
                      if (kDebugMode)
                        SettingsTile(
                          leading: const Icon(Icons.copy),
                          title: const Text('Hex ID Key'),
                          value: Text(
                            getPublicKeyDisplay(cc.roomContact.value.pubkey),
                          ),
                          onPressed: (context) {
                            Clipboard.setData(
                              ClipboardData(text: cc.roomContact.value.pubkey),
                            );
                            EasyLoading.showSuccess('ID Key copied');
                          },
                        ),
                      if (cc.roomObs.value.type == RoomType.common)
                        SettingsTile.navigation(
                          title: const Text('Nickname'),
                          leading: const Icon(CupertinoIcons.pencil),
                          value: Text(cc.roomContact.value.petname ?? ''),
                          onPressed: (context) async {
                            final usernameController = TextEditingController(
                              text: cc.roomContact.value.petname,
                            );
                            await Get.dialog(
                              CupertinoAlertDialog(
                                title: const Text('Nickname'),
                                content: Container(
                                  color: Colors.transparent,
                                  padding: const EdgeInsets.only(top: 15),
                                  child: TextField(
                                    controller: usernameController,
                                    autofocus: true,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (value) => handleUpdateName(
                                      usernameController.text.trim(),
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Nickname',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                actions: <Widget>[
                                  CupertinoDialogAction(
                                    child: const Text('Cancel'),
                                    onPressed: () {
                                      Get.back<void>();
                                    },
                                  ),
                                  CupertinoDialogAction(
                                    isDefaultAction: true,
                                    onPressed: () async {
                                      await handleUpdateName(
                                        usernameController.text.trim(),
                                      );
                                    },
                                    child: const Text('Confirm'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      SettingsTile(
                        description: Obx(
                          () =>
                              (cc.roomContact.value.lightning?.isNotEmpty ??
                                  false)
                              ? Text(cc.roomContact.value.lightning ?? '')
                              : Container(),
                        ),
                        leading: SizedBox(
                          width: 24,
                          child: Image.asset(
                            'assets/images/lightning.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        title: const Text('Lightning Address'),
                        trailing: Obx(
                          () =>
                              (cc.roomContact.value.lightning?.isEmpty ?? true)
                              ? textSmallGray(context, 'Not set')
                              : IconButton(
                                  icon: const Icon(
                                    CupertinoIcons.arrow_right_circle,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    if (cc
                                            .roomContact
                                            .value
                                            .lightning
                                            ?.isEmpty ??
                                        true) {
                                      return;
                                    }
                                    await Get.bottomSheet<void>(
                                      clipBehavior: Clip.antiAlias,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(4),
                                        ),
                                      ),
                                      PayInvoicePage(
                                        invoce: cc.roomContact.value.lightning,
                                        showScanButton: false,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      SettingsTile.navigation(
                        title: const Text('Security Settings'),
                        leading: const Icon(CupertinoIcons.lock_shield),
                        onPressed: (context) {
                          Get.toNamed(
                            Routes.roomSettingContactSecurity.replaceFirst(
                              ':id',
                              cc.roomObs.value.id.toString(),
                            ),
                            id: GetPlatform.isDesktop ? GetXNestKey.room : null,
                          );
                        },
                      ),
                      SettingsTile.switchTile(
                        title: const Text('Show Addresses in chat'),
                        initialValue: cc.showFromAndTo.value,
                        onToggle: (value) async {
                          cc.showFromAndTo.toggle();
                          Get.back<void>();
                        },
                        leading: const Icon(CupertinoIcons.mail),
                      ),
                      RoomUtil.pinRoomSection(cc),
                      if (cc.roomObs.value.encryptMode == EncryptMode.signal &&
                          GetPlatform.isIOS)
                        RoomUtil.muteSection(cc),
                      SettingsTile.navigation(
                        leading: const Icon(CupertinoIcons.search),
                        title: const Text('Search History'),
                        onPressed: (context) async {
                          await Get.to<void>(
                            () => SearchMessagesPage(
                              roomId: cc.roomObs.value.id,
                            ),
                            id: GetPlatform.isDesktop ? GetXNestKey.room : null,
                          );
                        },
                      ),
                    ],
                  ),
                  SettingsSection(
                    tiles: [
                      RoomUtil.mediaSection(cc),
                      SettingsTile.navigation(
                        leading: const Icon(CupertinoIcons.bitcoin),
                        title: const Text('Pay to Relay'),
                        onPressed: (context) async {
                          Get.toNamed(
                            Routes.roomSettingPayToRelay.replaceFirst(
                              ':id',
                              cc.roomObs.value.id.toString(),
                            ),
                            id: GetPlatform.isDesktop ? GetXNestKey.room : null,
                          );
                        },
                      ),
                    ],
                  ),
                  SettingsSection(
                    tiles: [
                      RoomUtil.autoCleanMessage(cc),
                      RoomUtil.clearHistory(cc),
                      SettingsTile(
                        leading: const Icon(
                          CupertinoIcons.trash,
                          color: Colors.red,
                        ),
                        title: const Text(
                          'Delete Chat Room',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: (context) async {
                          deleteChatRoomDialog(Get.context!, cc.roomObs.value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void deleteChatRoomDialog(BuildContext buildContext, Room room) {
    Get.dialog(
      CupertinoAlertDialog(
        title: const Text('Delete Chat Room?'),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text(
              'Cancel',
            ),
            onPressed: () async {
              Get.back<void>();
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              try {
                Get.back<void>();
                await RoomService.instance.deleteRoomHandler(
                  room.toMainPubkey,
                  room.identityId,
                );
                Get.find<HomeController>().loadIdentityRoomList(
                  room.identityId,
                );
                await Utils.offAllNamedRoom(Routes.root);
              } catch (e) {
                final msg = Utils.getErrorMessage(e);
                logger.e(msg, error: e, stackTrace: StackTrace.current);
                EasyLoading.showError('Error: $msg');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> handleUpdateName(String username) async {
    final contact0 = cc.roomContact.value..petname = username.trim();
    if (contact0.petname == '') {
      contact0.petname = null;
    }
    await ContactService.instance.saveContact(contact0);
    await RoomService.instance.refreshRoom(
      cc.roomObs.value,
      refreshContact: true,
    );

    Get.back<void>();
  }
}
