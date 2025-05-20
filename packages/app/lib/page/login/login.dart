import 'package:app/models/identity.dart';
import 'package:app/page/login/CreateAccount.dart';
import 'package:app/page/login/import_nsec.dart';
import 'package:app/page/login/import_seed_phrase.dart';
import 'package:app/page/routes.dart';
import 'package:app/page/setting/app_general_setting.dart';

import 'package:app/service/secure_storage.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(context) {
    return SafeArea(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: GetPlatform.isDesktop
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                    SizedBox(height: 32),
                    Text('Keychat is the super app for Bitcoiners',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontSize: 32)),
                    Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                            'Autonomous IDs, Bitcoin ecash wallet, secure chat, and rich Mini Apps — all in Keychat')),
                    Row(
                      spacing: 8,
                      mainAxisAlignment: GetPlatform.isMobile
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Chip(
                            label: Text('Autonomy'),
                            avatar: SvgPicture.asset('assets/images/wallet.svg',
                                width: 16, height: 16)),
                        Chip(
                            label: Text('Security'),
                            avatar: SvgPicture.asset(
                                'assets/images/security.svg',
                                width: 16,
                                height: 16)),
                        Chip(
                            label: Text('Richness'),
                            avatar: Image.asset('assets/images/recommend.png',
                                width: 16, height: 16)),
                      ],
                    )
                  ])),
              Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                        onPressed: () async {
                          try {
                            await SecureStorage.instance.clearAll();
                            var res = await Get.to(() => const CreateAccount());
                            if (res != null) {
                              Get.offAllNamed(Routes.root, arguments: true);
                            }
                          } catch (e, s) {
                            EasyLoading.showError(e.toString());
                            logger.e(e.toString(), stackTrace: s);
                          }
                        },
                        child: const Text("Create ID")),
                    SizedBox(height: 16),
                    OutlinedButton(
                        onPressed: () async {
                          Get.bottomSheet(
                              clipBehavior: Clip.antiAlias,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(4))),
                              getRecoverPage());
                        },
                        child: const Text("Recover ID")),
                  ])
            ])));
  }

  Widget getRecoverPage() {
    return SettingsList(platform: DevicePlatform.iOS, sections: [
      SettingsSection(title: const Text('Recover ID'), tiles: [
        SettingsTile.navigation(
          leading: const Icon(Icons.file_open),
          title: const Text("From Backup File"),
          onPressed: (context) {
            AppGeneralSetting.enableImportDB(context);
          },
        ),
        SettingsTile.navigation(
          leading: const Icon(Icons.local_activity),
          title: const Text("From Seed Phrase"),
          onPressed: (context) async {
            Identity? res = await Get.to(() => const ImportSeedPhrase());
            if (res != null) {
              Get.offAllNamed(Routes.root, arguments: true);
            }
          },
        ),
        SettingsTile.navigation(
          leading: const Icon(Icons.vpn_key),
          title: const Text("From Nsec"),
          onPressed: (context) async {
            Identity? res = await Get.to(() => const ImportNsec());
            if (res != null) {
              Get.offAllNamed(Routes.root, arguments: true);
            }
          },
        ),
      ]),
      if (GetPlatform.isAndroid)
        SettingsSection(tiles: [
          SettingsTile.navigation(
            leading: SvgPicture.asset('assets/images/logo/amber.svg',
                fit: BoxFit.contain, width: 20, height: 20),
            title: const Text("Login with Amber App"),
            onPressed: (context) async {
              var identity = await Utils.handleAmberLogin();
              if (identity != null) {
                Get.offAllNamed(Routes.root, arguments: true);
              }
            },
          )
        ]),
    ]);
  }
}
