import 'package:app/controller/home.controller.dart';
import 'package:app/models/identity.dart';
import 'package:app/page/login/CreateAccount.dart';
import 'package:app/page/login/import_nsec.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class SelectModeToCreateId extends StatefulWidget {
  const SelectModeToCreateId({super.key});

  @override
  _SelectModeToCreateIdState createState() => _SelectModeToCreateIdState();
}

class _SelectModeToCreateIdState extends State<SelectModeToCreateId> {
  @override
  Widget build(BuildContext context) {
    return SettingsList(platform: DevicePlatform.iOS, sections: [
      SettingsSection(title: const Text('Create ID'), tiles: [
        SettingsTile.navigation(
          leading: const Icon(Icons.local_activity),
          title: const Text("From Seed Phrase"),
          onPressed: (context) async {
            List<Identity> identities =
                Get.find<HomeController>().allIdentities.values.toList();
            List<String> npubs = identities.map((e) => e.npub).toList();
            String? mnemonic = await SecureStorage.instance.getPhraseWords();
            var res = await Get.to(
                () => CreateAccount(mnemonic: mnemonic, npubs: npubs),
                arguments: 'create');
            Get.back(result: res);
          },
        ),
        SettingsTile.navigation(
          leading: const Icon(Icons.vpn_key),
          title: const Text("From Nsec"),
          onPressed: (context) async {
            Identity? res = await Get.to(() => const ImportNsec());
            if (res != null) {
              Get.back(result: res);
              EasyLoading.showSuccess('Login success');
            }
          },
        ),
        if (GetPlatform.isAndroid)
          SettingsTile.navigation(
            leading: SvgPicture.asset(
              'assets/images/logo/amber.svg',
              fit: BoxFit.contain,
              width: 20,
              height: 20,
            ),
            title: const Text("Login with Amber App"),
            onPressed: (context) async {
              var res = await Utils.handleAmberLogin();
              if (res != null) {
                Get.back();
                EasyLoading.showSuccess('Login success');
              }
            },
          )
      ]),
    ]);
  }
}
