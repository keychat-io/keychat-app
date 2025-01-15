import 'package:app/controller/home.controller.dart';
import 'package:app/models/identity.dart';
import 'package:app/page/login/CreateAccount.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class SelectIdentityForBrowser extends StatefulWidget {
  final String host;
  const SelectIdentityForBrowser(this.host, {super.key});

  @override
  _SelectIdentityForBrowserState createState() =>
      _SelectIdentityForBrowserState();
}

class _SelectIdentityForBrowserState extends State<SelectIdentityForBrowser> {
  List<Identity> identities = [];
  @override
  void initState() {
    init();
    super.initState();
  }

  init() async {
    List<Identity> list =
        await IdentityService.instance.getEnableBrowserIdentityList();
    setState(() {
      identities = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsList(platform: DevicePlatform.iOS, sections: [
      if (identities.isNotEmpty)
        SettingsSection(
            title: Text('Request login to: ${widget.host}',
                style: Theme.of(context).textTheme.titleMedium),
            tiles: identities
                .map((iden) => SettingsTile(
                    leading: Utils.getRandomAvatar(iden.secp256k1PKHex,
                        height: 30, width: 30),
                    value: Text(getPublicKeyDisplay(iden.npub)),
                    title: Text(iden.displayName),
                    onPressed: (context) async {
                      Get.back(result: iden);
                    }))
                .toList()),
      SettingsSection(tiles: [
        SettingsTile(
            title: const Text("Create ID"),
            trailing: Icon(CupertinoIcons.add,
                color: Theme.of(Get.context!)
                    .iconTheme
                    .color
                    ?.withValues(alpha: 0.5),
                size: 22),
            onPressed: (context) async {
              List<Identity> identities =
                  Get.find<HomeController>().allIdentities.values.toList();
              List<String> npubs = identities.map((e) => e.npub).toList();
              String? mnemonic = await SecureStorage.instance.getPhraseWords();
              await Get.to(
                  () => CreateAccount(
                      showImportNsec: true,
                      type: "tab",
                      mnemonic: mnemonic,
                      npubs: npubs),
                  arguments: 'create');
              init();
            })
      ])
    ]);
  }
}
