import 'package:app/global.dart';
import 'package:flutter/services.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_ecash/components/SelectMint.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_ecash/Bills/cashu_transaction.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:easy_debounce/easy_throttle.dart';

import 'package:get/get.dart';

class CashuSendPage extends StatefulWidget {
  const CashuSendPage(this.isRoom, {super.key});
  final bool isRoom;

  @override
  _CashuSendPageState createState() => _CashuSendPageState();
}

class _CashuSendPageState extends State<CashuSendPage> {
  late EcashController ecashController;
  late String selectedMint;
  @override
  void initState() {
    ecashController = Get.find<EcashController>();
    ecashController.nameController.clear();
    ecashController.getBalance();
    selectedMint = ecashController.latestMintUrl.value;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
        child: Column(
          children: [
            Center(
              child: Text(
                'Send Sat(Cashu)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Obx(
              () => SelectMint(ecashController.latestMintUrl.value,
                  (String mint) {
                setState(() {
                  selectedMint = mint;
                  ecashController.latestMintUrl.value = mint;
                });
              }),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: TextField(
                      style: const TextStyle(fontSize: 16),
                      controller: ecashController.nameController,
                      keyboardType: TextInputType.number,
                      // textInputAction: TextInputAction.done,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.only(
                bottom: Get.isBottomSheetOpen ?? true
                    ? 0
                    : MediaQuery.of(context).viewInsets.bottom,
              ),
              child: FilledButton(
                style: ButtonStyle(
                  minimumSize: WidgetStateProperty.all(
                    const Size(double.infinity, 44),
                  ),
                ),
                child: const Text('Send'),
                onPressed: () async {
                  EasyThrottle.throttle(
                      'send_ecash', const Duration(milliseconds: 2000),
                      () async {
                    if (GetPlatform.isMobile) {
                      HapticFeedback.lightImpact();
                    }
                    final amountString =
                        ecashController.nameController.text.trim();
                    if (amountString.isEmpty) {
                      EasyLoading.showToast('Please input amount');
                      return;
                    }
                    var amount = 0;
                    try {
                      amount = int.parse(amountString);
                    } catch (e) {
                      EasyLoading.showToast('Invalid amount');
                      return;
                    }
                    if (amount == 0) {
                      EasyLoading.showToast('Amount should > 0');
                      return;
                    }
                    final balance =
                        ecashController.getBalanceByMint(selectedMint);
                    if (balance < amount) {
                      EasyLoading.showToast('Insufficient balance');
                      return;
                    }
                    try {
                      EasyLoading.show(status: 'Generating...');
                      final cashuInfoModel = await CashuUtil.getCashuA(
                        amount: amount,
                        mints: [selectedMint],
                      );

                      EasyLoading.showToast(
                        'Success',
                        duration: const Duration(seconds: 2),
                      );
                      await ecashController.getBalance();
                      await ecashController.getRecentTransactions();

                      EasyLoading.dismiss();
                      if (widget.isRoom) {
                        Get.back(result: cashuInfoModel);
                        return;
                      }
                      if (Get.isBottomSheetOpen ?? false) {
                        Get.back<void>();
                      }
                      Get.to(
                        () => CashuTransactionPage(
                          transaction: cashuInfoModel.toCashuTransaction(),
                        ),
                        id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
                      );
                    } catch (e, s) {
                      final msg = Utils.getErrorMessage(e);
                      if (msg.contains('Spent')) {
                        await rust_cashu.checkProofs();
                        EasyLoading.showError(
                          'Exception: Token already spent. Please retry',
                          duration: const Duration(seconds: 3),
                        );
                        return;
                      }
                      EasyLoading.showError(
                        msg,
                        duration: const Duration(seconds: 3),
                      );
                      logger.e(msg, error: e, stackTrace: s);
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
