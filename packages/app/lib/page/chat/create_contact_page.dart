import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/qrscan.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/service/signal_chat.service.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:share_plus/share_plus.dart';

const _invalidContactPubkeyMessage = 'Please input a valid npub or hex pubkey';
final _hexPubkeyPattern = RegExp(r'^[0-9a-fA-F]{64}$');
final _npubPattern = RegExp(
  r'^npub1[qpzry9x8gf2tvdw0s3jn54khce6mua7l]{58}$',
);

/// Normalizes the Add Contact text field into the actual contact key input.
String normalizeAddContactInput(String rawInput) {
  var input = rawInput.trim();
  if (input.startsWith('https://www.keychat.io/u/')) {
    final uri = Uri.tryParse(input);
    if (uri?.queryParameters['k'] != null) {
      input = Uri.decodeComponent(uri!.queryParameters['k']!).trim();
    }
  }
  return input;
}

/// Returns true when [input] can safely be passed to Nostr pubkey FFI conversion.
bool isValidAddContactPubkeyInput(String input) {
  final normalizedInput = input.trim();
  return _hexPubkeyPattern.hasMatch(normalizedInput) ||
      _npubPattern.hasMatch(normalizedInput);
}

class AddtoContactsPage extends StatefulWidget {
  const AddtoContactsPage(this.defaultInput, {super.key});
  final String defaultInput;

  @override
  State<AddtoContactsPage> createState() => _SearchFriendsState();
}

class _SearchFriendsState extends State<AddtoContactsPage> {
  late TextEditingController _controller;
  late TextEditingController _helloController;
  late Identity selectedIdentity;
  HomeController homeController = Get.find<HomeController>();
  @override
  void initState() {
    selectedIdentity = homeController.getSelectedIdentity();
    _controller = TextEditingController(text: widget.defaultInput);
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
        centerTitle: true,
        title: const Text('Add Contact'),
        actions: [
          Utils.selectIdentityIconButton(
            identity: selectedIdentity,
            onChanged: (identity) {
              if (identity == null) return;
              setState(() {
                selectedIdentity = identity;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      textInputAction: TextInputAction.done,
                      maxLines: 4,
                      minLines: 1,
                      controller: _controller,
                      // autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Link or Key',
                        border: const OutlineInputBorder(),
                        suffixIcon: GetPlatform.isMobile
                            ? IconButton(
                                icon: const Icon(
                                  CupertinoIcons.qrcode_viewfinder,
                                ),
                                onPressed: () async {
                                  final qrCode = await QrScanService.instance
                                      .handleQRScan();
                                  if (qrCode != null) _controller.text = qrCode;
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                      controller: _helloController,
                      decoration: const InputDecoration(
                        labelText: 'Say Hi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  final url =
                      'https://www.keychat.io/u/?k=${selectedIdentity.npub}';
                  Get.dialog(
                    CupertinoAlertDialog(
                      title: const Text('My Universal Link'),
                      content: Text(url),
                      actions: [
                        CupertinoActionSheetAction(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: url));
                            EasyLoading.showToast('Copied to clipboard');
                            Get.back<void>();
                          },
                          child: const Text('Copy'),
                        ),
                        CupertinoActionSheetAction(
                          onPressed: () {
                            Get
                              ..back<void>()
                              ..dialog(
                                CupertinoAlertDialog(
                                  content: SizedBox(
                                    height: 240,
                                    width: 240,
                                    child: Utils.genQRImage(url, size: 240),
                                  ),
                                  actions: [
                                    CupertinoDialogAction(
                                      onPressed: Get.back,
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                          },
                          child: const Text('QR Code'),
                        ),
                        CupertinoActionSheetAction(
                          onPressed: () {
                            SharePlus.instance.share(
                              ShareParams(uri: Uri.tryParse(url)),
                            );
                            Get.back<void>();
                          },
                          child: const Text('Share'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('My Universal Link'),
              ),
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _createContact,
                    child: const Text('Confirm'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createContact() async {
    final input = normalizeAddContactInput(_controller.text);

    // chat key
    if (input.length > 70) {
      final isBase = isBase64(input);
      if (isBase) {
        QRUserModel model;
        try {
          model = QRUserModel.fromShortString(input);
          logger.i('Parsed QRUserModel: $model');
        } catch (e, s) {
          final msg = Utils.getErrorMessage(e);
          logger.e(msg, stackTrace: s);
          EasyLoading.showToast('Invalid Input');
          return;
        }
        await RoomUtil.processUserQRCode(
          model,
          fromAddPage: true,
          identity: selectedIdentity,
        );
      } else {
        EasyLoading.showError('Error base64 format');
      }
      return;
    }
    // common private chat
    if (!isValidAddContactPubkeyInput(input)) {
      await EasyLoading.showError(_invalidContactPubkeyMessage);
      return;
    }

    try {
      // check if input is a bot npub
      final (hexPubkey, npub) = input.startsWith('npub')
          ? (rust_nostr.getHexPubkeyByBech32(bech32: input), input)
          : (input.toLowerCase(), rust_nostr.getBech32PubkeyByHex(hex: input));
      for (final bot in homeController.recommendBots) {
        if (bot['npub'] != npub) {
          continue;
        }
        try {
          final room = await RoomService.instance.getOrCreateRoom(
            hexPubkey,
            selectedIdentity.nostrIdentityKey,
            RoomStatus.enabled,
            contactName: bot['name'] as String?,
            type: RoomType.bot,
            identity: selectedIdentity,
          );
          await SignalChatService.instance.sendHelloMessage(
            room,
            selectedIdentity,
          );
          await ContactService.instance.addContactToFriend(
            pubkey: hexPubkey,
            identityId: selectedIdentity.id,
            name: bot['name'] as String?,
          );
          await Utils.toNamedRoom(room);
        } catch (e) {
          logger.e('Failed to create room for bot: $e');
          EasyLoading.showToast(
            'Failed to create room for bot: ${Utils.getErrorMessage(e)}',
          );
        }
        return;
      }

      final exitRoom = await RoomService.instance.getRoomByIdentity(
        hexPubkey,
        selectedIdentity.id,
      );

      // not exist rooms
      if (exitRoom == null) {
        await RoomService.instance.createRoomAndsendInvite(
          hexPubkey,
          greeting: _helloController.text.trim(),
          identity: selectedIdentity,
        );
        return;
      }

      return Utils.offAndToNamedRoom(exitRoom);
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
      logger.e(msg, stackTrace: s);
      EasyLoading.showError(msg);
    }
  }
}
