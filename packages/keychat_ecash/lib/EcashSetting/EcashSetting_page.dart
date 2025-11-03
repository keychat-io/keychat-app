import 'package:app/global.dart';
import 'package:app/rust_api.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/EcashSetting/EcashSetting_controller.dart';
import 'package:keychat_ecash/NostrWalletConnect/NostrWalletConnect_page.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:settings_ui/settings_ui.dart';

class EcashSettingPage extends GetView<EcashSettingController> {
  const EcashSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ecash Setting')),
      body: SettingsList(
        platform: DevicePlatform.iOS,
        sections: [
          SettingsSection(
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.pending),
                title: const Text('Receive Pendings'),
                onPressed: (context) async {
                  try {
                    EasyLoading.show(status: 'Receiving...');
                    var success = 0;
                    var failed = 0;
                    final errors = <String>[];
                    final list = await rust_cashu.getCashuPendingTransactions();
                    for (final tx in list) {
                      if (tx.status == TransactionStatus.pending) {
                        try {
                          await RustAPI.receiveToken(encodedToken: tx.token);
                          success++;
                        } catch (e, s) {
                          final msg = Utils.getErrorMessage(e);
                          errors.add(msg);
                          failed++;
                          logger.e('receive error', error: e, stackTrace: s);
                        }
                      }
                    }
                    EasyLoading.dismiss();
                    await Get.dialog(
                      CupertinoAlertDialog(
                        title: const Text('Receive Result'),
                        content: Column(
                          children: [
                            Text('Success: $success'),
                            Text('Failed: $failed'),
                            if (errors.isNotEmpty)
                              Column(
                                children: errors.map(Text.new).toList(),
                              ),
                          ],
                        ),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () {
                              Get.back<void>();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );

                    Get.find<EcashController>()
                      ..getBalance()
                      ..getRecentTransactions();
                  } catch (e, s) {
                    EasyLoading.showToast('Receive failed');
                    logger.e(e.toString(), error: e, stackTrace: s);
                  } finally {
                    Future.delayed(const Duration(seconds: 2))
                        .then((value) => EasyLoading.dismiss());
                  }
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.lock),
                title: const Text('Ecash Seed Phrase'),
                onPressed: (context) async {
                  final words = await SecureStorage.instance.getPhraseWords();
                  Get.dialog(
                    CupertinoAlertDialog(
                      title: const Text('Ecash Seed Phrase'),
                      content: Text(
                        words ??
                            'The seed phrase for the first ID is also the seed phrase for ecash.',
                      ),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: Get.back,
                          child: const Text('OK'),
                        ),
                        if (words != null)
                          CupertinoDialogAction(
                            isDefaultAction: true,
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: words),
                              );
                              EasyLoading.showSuccess('Copied');
                              Get.back<void>();
                            },
                            child: const Text('Copy'),
                          ),
                      ],
                    ),
                  );
                },
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.restore),
                title: const Text('Restore From Mint Server'),
                onPressed: (context) async {
                  await EcashUtils.restoreFromMintServer();
                },
              ),
              SettingsTile(
                leading: const Icon(Icons.auto_fix_high_sharp),
                title: const Text('Check Proofs'),
                description: const Text(
                  "「Check Proofs」 when you can't send cashu token",
                ),
                onPressed: (context) async {
                  try {
                    EasyLoading.show(status: 'Processing');
                    await rust_cashu.checkProofs();
                    EasyLoading.showToast('Success');
                  } catch (e) {
                    EasyLoading.dismiss();
                    final msg = Utils.getErrorMessage(e);
                    EasyLoading.showError(msg);
                  }
                },
              ),
            ],
          ),
          SettingsSection(
            tiles: [
              SettingsTile.navigation(
                leading: SvgPicture.asset(
                  'assets/images/logo/nwc.svg',
                  width: 24,
                  height: 24,
                ),
                title: const Text('Nostr Wallet Connect'),
                onPressed: (context) {
                  Get.to(
                    () => const NostrWalletConnectPage(),
                    id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
