import 'package:app/controller/home.controller.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/components.dart';
import 'package:app/service/qrscan.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/signal_chat.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app/models/models.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class AddtoContactsPage extends StatefulWidget {
  final String defaultInput;
  const AddtoContactsPage(this.defaultInput, {super.key});

  @override
  State<AddtoContactsPage> createState() => _SearchFriendsState();
}

class _SearchFriendsState extends State<AddtoContactsPage> {
  late TextEditingController _controller;
  late TextEditingController _helloController;
  HomeController homeController = Get.find<HomeController>();
  @override
  void initState() {
    _controller = TextEditingController(text: widget.defaultInput.toString());
    _helloController = TextEditingController();

    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _helloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
            leading: GestureDetector(
                onTap: () {
                  Get.back();
                },
                child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Row(children: [
                      const Icon(Icons.arrow_back_ios),
                      Utils.getRandomAvatar(
                          Get.find<HomeController>()
                              .getSelectedIdentity()
                              .secp256k1PKHex,
                          height: 22,
                          width: 22)
                    ]))),
            centerTitle: true,
            title: const Text("Add Contact")),
        body: SafeArea(
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16),
          child: Column(
            children: [
              Expanded(
                  child: Column(
                children: [
                  TextField(
                    textInputAction: TextInputAction.done,
                    maxLines: 2,
                    minLines: 1,
                    controller: _controller,
                    // autofocus: true,
                    decoration: InputDecoration(
                        labelText: 'Link or Key',
                        border: const OutlineInputBorder(),
                        suffixIcon: GetPlatform.isMobile
                            ? IconButton(
                                icon: const Icon(
                                    CupertinoIcons.qrcode_viewfinder),
                                onPressed: () async {
                                  String? qrCode = await QrScanService.instance
                                      .handleQRScan(autoProcess: false);
                                  if (qrCode != null) _controller.text = qrCode;
                                },
                              )
                            : null),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    textInputAction: TextInputAction.done,
                    maxLines: null,
                    controller: _helloController,
                    decoration: const InputDecoration(
                      labelText: 'Say Hi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              )),
              Center(
                child: Container(
                    constraints: BoxConstraints(maxWidth: 400),
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _createContact,
                      child: const Text('Confirm'),
                    )),
              ),
            ],
          ),
        )));
  }

  Future _createContact() async {
    String input = _controller.text.trim();
    if (input.startsWith('https://www.keychat.io/u/')) {
      input = input.replaceAll('https://www.keychat.io/u/', '');
    }
    // chat key
    if (input.length > 70) {
      bool isBase = isBase64(input);
      if (isBase) {
        QRUserModel model;
        try {
          model = QRUserModel.fromShortString(input);
        } catch (e, s) {
          String msg = Utils.getErrorMessage(e);
          logger.e(msg, stackTrace: s);
          EasyLoading.showToast('Invalid Input');
          return;
        }
        await RoomUtil.processUserQRCode(model, true);
      }
      return;
    }
    // common private chat
    try {
      Identity identity = Get.find<HomeController>().getSelectedIdentity();
      // check if input is a bot npub
      String npub = rust_nostr.getBech32PubkeyByHex(hex: input);
      String hexPubkey = rust_nostr.getHexPubkeyByBech32(bech32: npub);
      for (var bot in homeController.recommendBots) {
        if (bot['npub'] != npub) {
          continue;
        }
        try {
          Room room = await RoomService.instance.getOrCreateRoom(
              hexPubkey, identity.secp256k1PKHex, RoomStatus.enabled,
              contactName: bot['name'], type: RoomType.bot, identity: identity);
          await SignalChatService.instance.sendHelloMessage(room, identity);
          await Utils.toNamedRoom(room);
        } catch (e) {
          logger.e('Failed to create room for bot: $e');
          EasyLoading.showToast(
              'Failed to create room for bot: ${Utils.getErrorMessage(e)}');
        }
        return;
      }

      List<Room> rooms =
          await RoomService.instance.getCommonRoomByPubkey(hexPubkey);

      // exist rooms
      if (rooms.isEmpty) {
        await RoomService.instance.createRoomAndsendInvite(input,
            greeting: _helloController.text.trim(), identity: identity);
        return;
      }

      // found a room
      if (rooms.length == 1) {
        return Utils.offAndToNamedRoom(rooms[0]);
      }

      // found multiple rooms, dialog to select room
      await Get.dialog(SimpleDialog(
          title: const Text('Multi Rooms Found'),
          children: rooms.map((room) {
            return ListTile(
              title: Text(room.getRoomName()),
              subtitle: Text(
                  homeController.allIdentities[room.identityId]?.name ?? ''),
              onTap: () {
                Get.back();
                Utils.offAndToNamedRoom(room);
              },
            );
          }).toList()));
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      logger.e(msg, stackTrace: s);
      EasyLoading.showError(msg);
    }
  }
}
