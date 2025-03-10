import 'package:app/service/secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:app/utils.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import '../NostrWalletConnect/NostrWalletConnect_page.dart';
import './EcashSetting_controller.dart';

class EcashSettingPage extends GetView<EcashSettingController> {
  const EcashSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ecash Setting')),
      body: SettingsList(platform: DevicePlatform.iOS, sections: [
        SettingsSection(tiles: [
          SettingsTile.navigation(
            leading: const Icon(Icons.lock),
            title: const Text('Ecash Seed Phrase'),
            onPressed: (context) async {
              String? words = await SecureStorage.instance.getPhraseWords();
              Get.dialog(CupertinoAlertDialog(
                title: const Text('Ecash Seed Phrase'),
                content: Text(words ??
                    'The seed phrase for the first ID is also the seed phrase for ecash.'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('OK'),
                    onPressed: () {
                      Get.back();
                    },
                  ),
                  if (words != null)
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: words));
                        EasyLoading.showSuccess('Copied');
                        Get.back();
                      },
                      child: const Text('Copy'),
                    )
                ],
              ));
            },
          ),
          SettingsTile.navigation(
            leading: const Icon(Icons.restore),
            title: const Text('Restore From Mint Server'),
            onPressed: (context) async {
              try {
                EasyLoading.show(status: 'Proccessing');
                var ec = Get.find<EcashController>();

                if (ec.currentIdentity == null) {
                  EasyLoading.showError('No mnemonic');
                  return;
                }
                await ec.restore();
                await EasyLoading.showToast('Successfully');
              } catch (e, s) {
                String msg = Utils.getErrorMessage(e);
                logger.e(e.toString(), error: e, stackTrace: s);
                EasyLoading.showError(msg);
              }
            },
          ),
          SettingsTile(
            leading: const Icon(Icons.auto_fix_high_sharp),
            title: const Text('Check Proofs'),
            description:
                const Text('「Check Proofs」 when you can\'t send cashu token'),
            onPressed: (context) async {
              try {
                EasyLoading.show(status: 'Proccessing');
                var res = await rust_cashu.checkProofs();
                EasyLoading.showToast(
                    ''' Deleted: ${res.$1}, Hidden: ${res.$2}, Total: ${res.$3}''');
              } catch (e) {
                EasyLoading.dismiss();
                String msg = Utils.getErrorMessage(e);
                EasyLoading.showError(msg);
              }
            },
          ),
        ]),
        SettingsSection(tiles: [
          SettingsTile.navigation(
            leading: SvgPicture.asset(
              'assets/images/logo/nwc.svg',
              fit: BoxFit.contain,
              width: 24,
              height: 24,
            ),
            title: const Text("Nostr Wallet Connect"),
            onPressed: (context) {
              Get.to(() => const NostrWalletConnectPage());
            },
          ),
        ])
      ]),
    );
  }
}
