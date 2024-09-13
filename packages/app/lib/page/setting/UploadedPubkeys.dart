import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
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
  Map<String, List> titles = {
    'Identity Keys': <List<String>>[],
    'ShareKey Room Keys': <List<String>>[],
    'SignalChat Room Keys': <List<String>>[],
    'OneTime Keys': <List<String>>[]
  };
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Listening Pubkey Stats'),
        ),
        body: SettingsList(platform: DevicePlatform.iOS, sections: [
          SettingsSection(
              tiles: titles.keys
                  .map((e) => SettingsTile.navigation(
                      title: Text(e),
                      value: Text(titles[e]!.length.toString()),
                      onPressed: (context) async {
                        Get.to(() =>
                            UploadedPubkeysList(e, titles[e]! as List<String>));
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
    List<Identity> list = Get.find<HomeController>().identities.values.toList();
    idkeys.addAll(list.map((e) => e.secp256k1PKHex));

    List<String> shareKeyRooms = [];
    // sharing group 's mykey
    List<Room> rooms = await RoomService().getGroupsSharedKey();
    for (var room in rooms) {
      String? pubkey = room.mykey.value?.pubkey;
      if (pubkey != null) {
        shareKeyRooms.add(pubkey);
      }
    }

    List<String> signalChatRoom =
        await ContactService().getAllReceiveKeysSkipMute();
    List<String> oneTimeKeys = [];
    List<Mykey> newKeys = await IdentityService().getOneTimeKeys();
    for (var key in newKeys) {
      oneTimeKeys.add(key.pubkey);
    }
    setState(() {
      titles['Identity Keys'] = idkeys;
      titles['Shared Group Keys'] = shareKeyRooms;
      titles['SignalChat Room Keys'] = signalChatRoom;
      titles['OneTime Keys'] = oneTimeKeys;
    });
  }
}
