import 'dart:async';

import 'package:app/models/identity.dart';
import 'package:app/page/components.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class SelectIdentityForward extends StatefulWidget {
  const SelectIdentityForward(this.title, {super.key});
  final String title;

  @override
  _SelectIdentityForwardState createState() => _SelectIdentityForwardState();
}

class _SelectIdentityForwardState extends State<SelectIdentityForward> {
  List<Identity> identities = [];
  @override
  void initState() {
    unawaited(init());
    super.initState();
  }

  Future<void> init() async {
    final list = await IdentityService.instance.getEnableChatIdentityList();
    setState(() {
      identities = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return identities.isNotEmpty
        ? SettingsList(
            platform: DevicePlatform.iOS,
            sections: [
              SettingsSection(
                title: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                tiles: identities
                    .map(
                      (identity) => SettingsTile(
                        leading: Utils.getRandomAvatar(
                          identity.secp256k1PKHex,
                          localPath: identity.avatarLocalPath ??
                              identity.avatarFromRelayLocalPath,
                          size: 30,
                        ),
                        value: Text(getPublicKeyDisplay(identity.npub)),
                        title: Text(identity.displayName),
                        onPressed: (context) async {
                          Get.back(result: identity);
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          )
        : pageLoadingSpinKit();
  }
}
