import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/page/setting/UploadedPubkeysList.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:settings_ui/settings_ui.dart';

class UploadedPubkeys extends StatefulWidget {
  const UploadedPubkeys({super.key});

  @override
  _UploadedPubkeysState createState() => _UploadedPubkeysState();
}

class _UploadedPubkeysState extends State<UploadedPubkeys> {
  Map<String, List> titles = {};
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listening Pubkey Stats'),
      ),
      body: titles.keys.isEmpty
          ? pageLoadingSpinKit()
          : SettingsList(
              platform: DevicePlatform.iOS,
              sections: [
                SettingsSection(
                  tiles: titles.keys
                      .map(
                        (e) => SettingsTile.navigation(
                          title: Text(e),
                          value: Text(titles[e]!.length.toString()),
                          onPressed: (context) async {
                            Get.to(
                              () => UploadedPubkeysList(
                                e,
                                titles[e]! as List<String>,
                              ),
                            );
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
    );
  }

  @override
  void initState() {
    init();
    super.initState();
  }

  Future<void> init() async {
    final idkeys = <String>[];
    final skipedIdentityIds = await IdentityService.instance
        .getDisableChatIdentityIDList();
    final list = Get.find<HomeController>().allIdentities.values.toList();
    for (final item in list) {
      if (skipedIdentityIds.contains(item.id)) {
        continue;
      }
      idkeys.add(item.secp256k1PKHex);
    }

    // mls room's receive key
    final mlsPubkeys = <String>{};
    final mlsRooms = await RoomService.instance.getMlsRooms();
    for (final room in mlsRooms) {
      if (skipedIdentityIds.contains(room.identityId)) {
        continue;
      }
      mlsPubkeys.add(room.onetimekey!);
    }

    final signalChatRoom = await ContactService.instance
        .getAllReceiveKeysSkipMute(skipIDs: skipedIdentityIds);
    final oneTimeKeys = <String>[];
    final newKeys = await IdentityService.instance.getOneTimeKeys();
    for (final key in newKeys) {
      oneTimeKeys.add(key.pubkey);
    }
    setState(() {
      titles['Identity Keys'] = idkeys;
      titles['MLS Group Keys'] = mlsPubkeys.toList();
      titles['SignalChat Room Keys'] = signalChatRoom;
      titles['OneTime Keys'] = oneTimeKeys;
    });
  }
}
