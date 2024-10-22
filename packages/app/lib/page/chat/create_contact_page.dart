// ignore_for_file: use_build_context_synchronously

import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/components.dart';
import 'package:app/service/qrscan.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app/models/models.dart';

import '../../controller/home.controller.dart';
import '../../service/room.service.dart';

class AddtoContactsPage extends StatefulWidget {
  final String defaultInput;
  const AddtoContactsPage(this.defaultInput, {super.key});

  @override
  State<AddtoContactsPage> createState() => _SearchFriendsState();
}

class _SearchFriendsState extends State<AddtoContactsPage> {
  late TextEditingController _controller;
  late TextEditingController _helloController;
  // bool isBot = false;

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
        appBar: AppBar(centerTitle: true, title: const Text("Add Contacts")),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20),
          child: Column(
            children: [
              TextField(
                textInputAction: TextInputAction.done,
                maxLines: 8,
                minLines: 1,
                controller: _controller,
                // autofocus: true,
                decoration: InputDecoration(
                    labelText: 'QR Code or ID Key',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste),
                      onPressed: () async {
                        final clipboardData =
                            await Clipboard.getData('text/plain');
                        if (clipboardData != null) {
                          final pastedText = clipboardData.text;
                          if (pastedText != null && pastedText != '') {
                            _controller.text = pastedText;
                            _controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: _controller.text.length));
                          }
                        }
                      },
                    )),
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
              Padding(
                padding: const EdgeInsets.only(top: 20.0, bottom: 40),
                child: FilledButton(
                  onPressed: () async {
                    String input = _controller.text.trim();
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
                    await RoomService().createRoomAndsendInvite(input,
                        greeting: _helloController.text.trim());
                  },
                  style: ButtonStyle(
                      minimumSize: WidgetStateProperty.all(
                          const Size(double.infinity, 44))),
                  child: const Text('Confirm'),
                ),
              ),
              const SizedBox(height: 50),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(CupertinoIcons.qrcode),
                    title: const Text('My QR Code'),
                    onTap: () async {
                      Identity identity =
                          Get.find<HomeController>().getSelectedIdentity();
                      await showMyQrCode(context, identity, false);
                    },
                    trailing: const Icon(CupertinoIcons.right_chevron),
                  ),
                  ListTile(
                    leading: const Icon(CupertinoIcons.qrcode_viewfinder),
                    title: const Text('Scan QR Code'),
                    onTap: () async {
                      String? result =
                          await QrScanService.instance.handleQRScan();
                      if (result != null) {
                        QrScanService.instance.processQRResult(result);
                      }
                    },
                    trailing: const Icon(CupertinoIcons.right_chevron),
                  )
                ]),
              )
            ],
          ),
        ));
  }
}
