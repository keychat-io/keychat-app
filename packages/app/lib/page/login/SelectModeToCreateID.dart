import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/page/login/CreateAccount.dart';
import 'package:keychat/page/login/import_nsec.dart';
import 'package:keychat/page/widgets/legal_consent_widget.dart';
import 'package:keychat/service/legal_consent.service.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:keychat/utils.dart';
import 'package:settings_ui/settings_ui.dart';

class SelectModeToCreateId extends StatefulWidget {
  const SelectModeToCreateId({super.key});

  @override
  State<SelectModeToCreateId> createState() => _SelectModeToCreateIdState();
}

class _SelectModeToCreateIdState extends State<SelectModeToCreateId> {
  bool _acceptedLegal = false;

  bool get _hasIdentity => Get.find<HomeController>().allIdentities.isNotEmpty;

  bool get _requiresLegalConsent {
    return LegalConsentService.shouldRequestConsent(hasIdentity: _hasIdentity);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsList(
      platform: DevicePlatform.iOS,
      sections: [
        SettingsSection(
          title: const Text('Create ID'),
          tiles: [
            SettingsTile.navigation(
              leading: const Icon(Icons.local_activity),
              title: const Text('From Seed Phrase'),
              onPressed: (context) async {
                if (!await _canContinueWithLegalConsent()) return;
                final identities = Get.find<HomeController>()
                    .allIdentities
                    .values
                    .toList();
                final npubs = identities.map((e) => e.npub).toList();
                final mnemonic = await SecureStorage.instance.getPhraseWords();
                final res = await Get.to<Object?>(
                  () => CreateAccount(mnemonic: mnemonic, npubs: npubs),
                  arguments: 'create',
                );
                if (res != null) {
                  await _saveLegalConsentIfNeeded();
                }
                Get.back(result: res);
              },
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.vpn_key),
              title: const Text('From Nsec'),
              onPressed: (context) async {
                if (!await _canContinueWithLegalConsent()) return;
                final res = await Get.to<Object?>(() => const ImportNsec());
                if (res != null) {
                  await _saveLegalConsentIfNeeded();
                  Get.back(result: res);
                  await EasyLoading.showSuccess('Login success');
                }
              },
            ),
            if (GetPlatform.isAndroid)
              SettingsTile.navigation(
                leading: SvgPicture.asset(
                  'assets/images/logo/amber.svg',
                  width: 20,
                  height: 20,
                ),
                title: const Text('Login with Amber App'),
                onPressed: (context) async {
                  if (!await _canContinueWithLegalConsent()) return;
                  final res = await Utils.handleAmberLogin();
                  if (res != null) {
                    await _saveLegalConsentIfNeeded();
                    Get.back<void>();
                    await EasyLoading.showSuccess('Login success');
                  }
                },
              ),
          ],
        ),
        if (_requiresLegalConsent)
          SettingsSection(
            tiles: [
              CustomSettingsTile(
                child: LegalConsentWidget(
                  value: _acceptedLegal,
                  onChanged: (value) {
                    setState(() {
                      _acceptedLegal = value;
                    });
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<bool> _canContinueWithLegalConsent() async {
    return LegalConsentService.canContinue(
      hasIdentity: _hasIdentity,
      acceptedLegal: _acceptedLegal,
    );
  }

  Future<void> _saveLegalConsentIfNeeded() async {
    await LegalConsentService.saveAcceptedVersionIfNeeded(
      hasIdentity: _hasIdentity,
    );
  }
}
