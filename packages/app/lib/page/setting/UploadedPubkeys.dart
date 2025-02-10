import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
import 'package:app/page/components.dart';
import 'package:app/page/setting/UploadedPubkeysList.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/room.service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
            : SettingsList(platform: DevicePlatform.iOS, sections: [
                SettingsSection(
                    tiles: titles.keys
                        .map((e) => SettingsTile.navigation(
                            title: Text(e),
                            value: Text(titles[e]!.length.toString()),
                            onPressed: (context) async {
                              Get.to(() => UploadedPubkeysList(
                                  e, titles[e]! as List<String>));
                            }))
                        .toList())
              ]));
  }

  @override
  void initState() {
    init();
    super.initState();
  }

  void init() async {
    List<String> idkeys = [];
    List<int> skipedIdentityIds =
        await IdentityService.instance.getDisableChatIdentityIDList();
    List<Identity> list =
        Get.find<HomeController>().allIdentities.values.toList();
    for (var item in list) {
      if (skipedIdentityIds.contains(item.id)) {
        continue;
      }
      idkeys.add(item.secp256k1PKHex);
    }

    // mls room's receive key
    Set<String> mlsPubkeys = {};
    List<Room> mlsRooms = await RoomService.instance.getMlsRooms();
    for (Room room in mlsRooms) {
      if (skipedIdentityIds.contains(room.identityId)) {
        continue;
      }
      mlsPubkeys.add(room.onetimekey!);
    }

    List<String> signalChatRoom = await ContactService.instance
        .getAllReceiveKeysSkipMute(skipIDs: skipedIdentityIds);
    List<String> oneTimeKeys = [];
    List<Mykey> newKeys = await IdentityService.instance.getOneTimeKeys();
    for (var key in newKeys) {
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
