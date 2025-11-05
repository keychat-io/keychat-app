import 'package:keychat/models/identity.dart';
import 'package:keychat/page/login/CreateAccount.dart';
import 'package:keychat/page/login/import_nsec.dart';
import 'package:keychat/page/login/import_seed_phrase.dart';
import 'package:keychat/page/routes.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: GetPlatform.isDesktop
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'Keychat is the super app for Bitcoiners',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 32),
                    ),
                  ),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Autonomous IDs, Bitcoin ecash wallet, secure chat, and rich Mini Apps — all in Keychat',
                      ),
                    ),
                  ),
                  Row(
                    spacing: 8,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Chip(
                        label: const Text('Autonomy'),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        avatar: SvgPicture.asset(
                          'assets/images/wallet.svg',
                          width: 16,
                          height: 16,
                        ),
                      ),
                      Chip(
                        label: const Text('Security'),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        avatar: SvgPicture.asset(
                          'assets/images/security.svg',
                          width: 16,
                          height: 16,
                        ),
                      ),
                      Chip(
                        label: const Text('Richness'),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        avatar: Image.asset(
                          'assets/images/recommend.png',
                          width: 16,
                          height: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        try {
                          final res = await Get.to(() => const CreateAccount());
                          if (res != null) {
                            Get.offAllNamed(Routes.root, arguments: true);
                          }
                        } catch (e, s) {
                          EasyLoading.showError(e.toString());
                          logger.e(e.toString(), stackTrace: s);
                        }
                      },
                      child: const Text('Create ID'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        Get.bottomSheet(
                          clipBehavior: Clip.antiAlias,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          getRecoverPage(),
                        );
                      },
                      child: const Text('Recover ID'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget getRecoverPage() {
    return SettingsList(
      platform: DevicePlatform.iOS,
      sections: [
        SettingsSection(
          title: const Text('Recover ID'),
          tiles: [
            SettingsTile.navigation(
              leading: const Icon(Icons.file_open),
              title: const Text('From Backup File'),
              onPressed: (context) {
                Utils.enableImportDB();
              },
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.local_activity),
              title: const Text('From Seed Phrase'),
              onPressed: (context) async {
                final res = await Get.to(() => const ImportSeedPhrase());
                if (res != null) {
                  Get.offAllNamed(Routes.root, arguments: true);
                }
              },
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.vpn_key),
              title: const Text('From Nsec'),
              onPressed: (context) async {
                final res = await Get.to(() => const ImportNsec());
                if (res != null) {
                  Get.offAllNamed(Routes.root, arguments: true);
                }
              },
            ),
          ],
        ),
        if (GetPlatform.isAndroid)
          SettingsSection(
            tiles: [
              SettingsTile.navigation(
                leading: SvgPicture.asset(
                  'assets/images/logo/amber.svg',
                  width: 20,
                  height: 20,
                ),
                title: const Text('Login with Amber App'),
                onPressed: (context) async {
                  try {
                    final identity = await Utils.handleAmberLogin();
                    if (identity != null) {
                      Get.offAllNamed(Routes.root, arguments: true);
                    }
                  } catch (e, s) {
                    EasyLoading.showError(e.toString());
                    logger.e(e.toString(), stackTrace: s);
                  }
                },
              ),
            ],
          ),
      ],
    );
  }
}
