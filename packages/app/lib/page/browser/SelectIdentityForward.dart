import 'package:app/models/identity.dart';
import 'package:app/page/components.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class SelectIdentityForward extends StatefulWidget {
  final String title;
  const SelectIdentityForward(this.title, {super.key});

  @override
  _SelectIdentityForwardState createState() => _SelectIdentityForwardState();
}

class _SelectIdentityForwardState extends State<SelectIdentityForward> {
  List<Identity> identities = [];
  @override
  void initState() {
    init();
    super.initState();
  }

  init() async {
    List<Identity> list =
        await IdentityService.instance.getEnableChatIdentityList();
    setState(() {
      identities = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return identities.isNotEmpty
        ? SafeArea(
            child: SettingsList(platform: DevicePlatform.iOS, sections: [
            SettingsSection(
                title: Text(widget.title,
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
          ]))
        : pageLoadingSpinKit();
  }
}
