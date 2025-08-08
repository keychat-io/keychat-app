import 'package:app/models/identity.dart';
import 'package:app/page/login/SelectModeToCreateID.dart';
import 'package:app/service/identity.service.dart';
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
    return SafeArea(
        child: SettingsList(platform: DevicePlatform.iOS, sections: [
      if (identities.isNotEmpty)
        SettingsSection(
            title: Text('Request login to: ${widget.host}',
                style: Theme.of(context).textTheme.titleMedium),
            tiles: identities
                .map((iden) => SettingsTile(
                    leading: Utils.getRandomAvatar(iden.secp256k1PKHex,
                        httpAvatar: iden.avatarFromRelay,
                        height: 30,
                        width: 30),
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
              await Get.bottomSheet(
                  clipBehavior: Clip.antiAlias,
                  shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(4))),
                  const SelectModeToCreateId());
              init();
            })
      ])
    ]));
  }
}
