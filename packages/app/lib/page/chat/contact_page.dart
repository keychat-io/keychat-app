import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/page/components.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/signal_chat.service.dart';
import 'package:app/utils.dart';
import 'package:avatar_plus/avatar_plus.dart';
import 'package:convert/convert.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:settings_ui/settings_ui.dart';

// ignore: must_be_immutable
class ContactPage extends StatelessWidget {
  ContactPage({
    required this.identityId,
    required this.contact,
    required this.title,
    super.key,
    this.greeting,
  });
  late Contact contact;
  final int identityId;
  late String title;
  QRUserModel? model;
  String? greeting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(title),
      ),
      body: SettingsList(
        platform: DevicePlatform.iOS,
        sections: [
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
                  child: Text(
                    contact.npubkey.isNotEmpty
                        ? contact.npubkey
                        : rust_nostr.getBech32PubkeyByHex(hex: contact.pubkey),
                  ),
                ),
                onPressed: (context) async {
                  if (contact.npubkey.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: contact.npubkey));
                    return;
                  }
                  final npubkey =
                      rust_nostr.getBech32PubkeyByHex(hex: contact.pubkey);
                  Clipboard.setData(ClipboardData(text: npubkey));
                  Get.back<void>();
                },
              ),
              if (model != null) fromQRCode(),
              if (model == null)
                RoomUtil.fromContactClick(contact.pubkey, identityId, greeting),
            ],
          ),
        ],
      ),
    );
  }

  SettingsTile fromQRCode() {
    return SettingsTile(
      title: FutureBuilder(
        future:
            RoomService.instance.getRoomByIdentity(contact.pubkey, identityId),
        builder: (context, snapshot) {
          final room = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              if (room != null)
                OutlinedButton(
                  onPressed: () {
                    Utils.offAndToNamedRoom(room);
                  },
                  child: const Text('Start to Chat'),
                ),
              FilledButton(
                onPressed: () async {
                  if (room != null) {
                    await ContactService.instance.saveContactFromQrCode(
                      identityId: room.identityId,
                      pubkey: room.toMainPubkey,
                      name: model!.name,
                      avatarRemoteUrl: model!.avatar,
                      lightning: model!.lightning,
                    );
                    await SignalChatService.instance.resetSignalSession(room);
                    return;
                  }
                  EasyThrottle.throttle(
                      'Add_contact', const Duration(seconds: 2), () async {
                    late Room room0;
                    try {
                      EasyLoading.show(status: 'Processing...');
                      final identity =
                          Get.find<HomeController>().allIdentities[identityId]!;
                      room0 = await RoomService.instance.createPrivateRoom(
                        toMainPubkey: contact.pubkey,
                        identity: identity,
                        name: contact.displayName,
                        status: RoomStatus.enabled,
                        curve25519PkHex: model?.curve25519PkHex,
                        onetimekey: model?.onetimekey,
                        encryptMode: EncryptMode.signal,
                        contact: contact,
                      );

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
                            'Signal Session create failed. Please generate a new QR Code',
                          );
                          return;
                        }
                        final res = await Get.find<ChatxService>().addRoomKPA(
                          room: room0,
                          bobSignedId: model!.signedId,
                          bobSignedPublic: Uint8List.fromList(
                            hex.decode(model!.signedPublic),
                          ),
                          bobSignedSignature: Uint8List.fromList(
                            hex.decode(model!.signedSignature),
                          ),
                          bobPrekeyId: model!.prekeyId,
                          bobPrekeyPublic: Uint8List.fromList(
                            hex.decode(model!.prekeyPubkey),
                          ),
                        );
                        if (!res) {
                          EasyLoading.showError(
                            'Signal Session create failed. Please generate a new QR Code',
                          );
                          return;
                        }
                        await SignalChatService.instance.sendMessage(
                          room0,
                          RoomUtil.getHelloMessage(identity.displayName),
                        );
                        await ContactService.instance.addContactToFriend(
                          pubkey: room0.toMainPubkey,
                          identityId: room0.identityId,
                          name: contact.displayName,
                        );
                        EasyLoading.showSuccess('Successfully added');
                      }
                    } catch (e, s) {
                      EasyLoading.showError(
                        Utils.getErrorMessage(e),
                        duration: const Duration(seconds: 3),
                      );
                      logger.e(e.toString(), error: e, stackTrace: s);
                    } finally {
                      Future.delayed(const Duration(seconds: 2))
                          .then((c) => EasyLoading.dismiss());
                    }
                    Get.find<HomeController>()
                        .loadIdentityRoomList(room0.identityId);
                    await Utils.offAndToNamedRoom(room0);
                    Get.find<HomeController>()
                        .loadIdentityRoomList(room0.identityId);
                  });
                },
                child: Text(room == null ? 'Add' : 'Reset Signal Session'),
              ),
            ],
          );
        },
      ),
    );
  }
}
