import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:app/utils.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import './EcashSetting_controller.dart';

class EcashSettingPage extends GetView<EcashSettingController> {
  const EcashSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    EcashController ec = Get.find<EcashController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setting'),
      ),
      body: SettingsList(platform: DevicePlatform.iOS, sections: [
        SettingsSection(tiles: [
          SettingsTile.navigation(
            leading: getRandomAvatar(ec.currentIdentity!.secp256k1PKHex,
                height: 30, width: 30),
            title: Text(
              ec.currentIdentity!.displayName.length > 8
                  ? "${ec.currentIdentity!.displayName.substring(0, 8)}..."
                  : ec.currentIdentity!.displayName,
            ),
            onPressed: (context) {
              Get.dialog(CupertinoAlertDialog(
                content: const Text(
                    'The seed phrase for the first ID is also the seed phrase for ecash.'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('OK'),
                    onPressed: () {
                      Get.back();
                    },
                  )
                ],
              ));
            },
          ),
          SettingsTile(
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
        ]),
        SettingsSection(tiles: [
          SettingsTile(
            leading: const Icon(Icons.auto_fix_high_sharp),
            title: const Text('Check Proofs'),
            description:
                const Text('Click it when you can\'t send cashu token'),
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
        ])
      ]),
    );
  }
}
