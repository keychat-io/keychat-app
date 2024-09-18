import 'package:app/page/chat/RoomUtil.dart';
import 'package:avatar_plus/avatar_plus.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:app/service/chatx.service.dart';
import 'package:app/service/signal_chat.service.dart';
import 'package:convert/convert.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:settings_ui/settings_ui.dart';
import '../../controller/home.controller.dart';
import 'package:app/models/models.dart';

import '../../service/room.service.dart';
import '../../utils.dart';
import '../components.dart';

// ignore: must_be_immutable
class ContactPage extends StatelessWidget {
  late Contact contact;
  final int identityId;
  late String title;
  QRUserModel? model;
  String? greeting;
  ContactPage(
      {super.key,
      required this.identityId,
      required this.contact,
      required this.title,
      this.greeting});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(title),
      ),
      body: SettingsList(platform: DevicePlatform.iOS, sections: [
        SettingsSection(
          tiles: [
            SettingsTile(
              title: const Text('Avatar'),
              value: AvatarPlus(
                contact.pubkey,
                height: 40,
                width: 40,
              ),
            ),
            SettingsTile(
              title: const Text('Nickname'),
              value: textP(contact.displayName),
            ),
            SettingsTile(
              title: const Text('ID Key'),
              value: Flexible(
                child: Text(contact.npubkey.isNotEmpty
                    ? contact.npubkey
                    : rust_nostr.getBech32PubkeyByHex(hex: contact.pubkey)),
              ),
              onPressed: (context) async {
                if (contact.npubkey.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: contact.npubkey));
                  return;
                }
                String npubkey =
                    rust_nostr.getBech32PubkeyByHex(hex: contact.pubkey);
                Clipboard.setData(ClipboardData(text: npubkey));
                Get.back();
              },
            ),
            if (model != null) fromQRCode(),
            if (model == null)
              RoomUtil.fromContactClick(contact.pubkey, identityId, greeting),
          ],
        )
      ]),
    );
  }

  SettingsTile fromQRCode() {
    return SettingsTile(
      title: FutureBuilder(
          future: RoomService().getRoomByIdentity(contact.pubkey, identityId),
          builder: (context, snapshot) {
            Room? room = snapshot.data;
            return FilledButton(
              onPressed: () async {
                EasyThrottle.throttle('Add_contact', const Duration(seconds: 2),
                    () async {
                  // bool roomIsNull = room == null;
                  late Room room0;
                  try {
                    EasyLoading.show(status: 'Proccessing...');
                    Identity identity =
                        Get.find<HomeController>().identities[identityId]!;
                    room0 = await RoomService().createPrivateRoom(
                        toMainPubkey: contact.pubkey,
                        identity: identity,
                        name: contact.displayName,
                        status: RoomStatus.enabled,
                        curve25519PkHex: model?.curve25519PkHex,
                        onetimekey: model?.onetimekey,
                        encryptMode: EncryptMode.signal,
                        contact: contact);

                    //delete signal session
                    if (room != null) {
                      await Get.find<ChatxService>()
                          .deleteSignalSessionKPA(room);
                      if (model?.curve25519PkHex != null) {
                        room.curve25519PkHex = model?.curve25519PkHex;
                      }
                    }
                    if (room0.curve25519PkHex != null &&
                        model?.signedId != null) {
                      if (model == null) {
                        EasyLoading.showError(
                            "Signal Session create failed. Please generate a new QR Code");
                        return;
                      }
                      bool res = await Get.find<ChatxService>().addRoomKPA(
                          room: room0,
                          bobSignedId: model!.signedId,
                          bobSignedPublic: Uint8List.fromList(
                              hex.decode(model!.signedPublic)),
                          bobSignedSignature: Uint8List.fromList(
                              hex.decode(model!.signedSignature)),
                          bobPrekeyId: model!.prekeyId,
                          bobPrekeyPublic: Uint8List.fromList(
                              hex.decode(model!.prekeyPubkey)));
                      if (!res) {
                        EasyLoading.showError(
                            "Signal Session create failed. Please generate a new QR Code");
                        return;
                      }
                      await SignalChatService().sendMessage(room0,
                          RoomUtil.getHelloMessage(identity.displayName));
                      EasyLoading.showSuccess('Successfully added');
                    }
                  } catch (e, s) {
                    EasyLoading.showError(Utils.getErrorMessage(e),
                        duration: const Duration(seconds: 3));
                    logger.e(e.toString(), error: e, stackTrace: s);
                  } finally {
                    Future.delayed(const Duration(seconds: 2))
                        .then((c) => EasyLoading.dismiss());
                  }
                  await Get.find<HomeController>()
                      .loadIdentityRoomList(room0.identityId);
                  await Get.offAndToNamed('/room/${room0.id}',
                      arguments: room0);
                  await Get.find<HomeController>()
                      .loadIdentityRoomList(room0.identityId);
                });
              },
              child: Text(room == null ? 'Add' : 'Reset Signal Session'),
            );
          }),
    );
  }
}
