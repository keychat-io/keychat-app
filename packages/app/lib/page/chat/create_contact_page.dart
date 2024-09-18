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
        appBar: AppBar(
          centerTitle: true,
          title: const Text("Add Contacts"),
        ),
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
                    labelText: 'QRCode Or IDKey',
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
              const SizedBox(
                height: 20,
              ),
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

                    if (input.length > 64) {
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
                    await RoomService().createRoomAndsendInvite(input,
                        greeting: _helloController.text.trim());
                  },
                  child: const Text('Send'),
                ),
              ),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(CupertinoIcons.qrcode),
                    title: const Text('My QRCode'),
                    onTap: () async {
                      Identity identity =
                          Get.find<HomeController>().getSelectedIdentity();
                      await showMyQrCode(context, identity, false);
                    },
                    trailing: const Icon(CupertinoIcons.right_chevron),
                  ),
                  ListTile(
                    leading: const Icon(CupertinoIcons.person),
                    title: const Text('My IDKey'),
                    onTap: () async {
                      Identity identity =
                          Get.find<HomeController>().getSelectedIdentity();
                      Clipboard.setData(ClipboardData(text: identity.npub));
                      EasyLoading.showToast('Copied');
                    },
                    trailing: const Icon(Icons.copy),
                  ),
                  ListTile(
                    leading: const Icon(CupertinoIcons.qrcode_viewfinder),
                    title: const Text('Scan QRCode'),
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
