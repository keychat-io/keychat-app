import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rustCashu;
import 'package:flutter/cupertino.dart';
import 'package:keychat_ecash/Bills/ecash_bill_controller.dart';
import 'package:keychat_ecash/components/SelectMint.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:app/models/embedded/cashu_info.dart';
import 'package:keychat_ecash/Bills/cashu_transaction.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class CashuSendPage extends StatefulWidget {
  final bool isRoom;
  const CashuSendPage(this.isRoom, {super.key});

  @override
  _CashuSendPageState createState() => _CashuSendPageState();
}

class _CashuSendPageState extends State<CashuSendPage> {
  late EcashController cashuController;
  late String selectedMint;
  @override
  void initState() {
    cashuController = Get.find<EcashController>();
    cashuController.nameController.clear();
    cashuController.getBalance();
    selectedMint = cashuController.latestMintUrl.value;
    super.initState();
  }

  @override
  Widget build(context) {
    return SafeArea(
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
            decoration:
                BoxDecoration(color: Theme.of(context).colorScheme.surface),
            child: Column(children: [
              Center(
                child: Text(
                  'Send Sat(Cashu)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Obx(() => SelectMint(cashuController.latestMintUrl.value,
                      (String mint) {
                    setState(() {
                      selectedMint = mint;
                      cashuController.latestMintUrl.value = mint;
                    });
                  })),
              Expanded(
                  child: SingleChildScrollView(
                      child: Form(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: TextField(
                    style: const TextStyle(fontSize: 16),
                    controller: cashuController.nameController,
                    keyboardType: TextInputType.number,
                    // textInputAction: TextInputAction.done,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ))),
              const SizedBox(height: 16),
              Padding(
                  padding: EdgeInsets.only(
                      bottom: Get.isBottomSheetOpen ?? true
                          ? 0
                          : MediaQuery.of(context).viewInsets.bottom),
                  child: FilledButton(
                    style: ButtonStyle(
                        minimumSize: WidgetStateProperty.all(
                            const Size(double.infinity, 44))),
                    child: const Text(
                      'Send',
                    ),
                    onPressed: () async {
                      String amountString =
                          cashuController.nameController.text.trim();
                      if (amountString.isEmpty) {
                        EasyLoading.showToast('Please input amount');
                        return;
                      }
                      int amount = int.parse(amountString);
                      if (amount == 0) {
                        EasyLoading.showToast('Amount should > 0');
                        return;
                      }
                      int balance =
                          cashuController.getBalanceByMint(selectedMint);
                      if (balance < amount) {
                        EasyLoading.showToast('Insufficient balance');
                        return;
                      }
                      try {
                        EasyLoading.show(status: 'Generating...');
                        CashuInfoModel? cashuInfoModel =
                            await CashuUtil.getCashuA(
                                amount: amount, mints: [selectedMint]);

                        EasyLoading.showToast('Success',
                            duration: const Duration(seconds: 2));
                        cashuController.getBalance();
                        getGetxController<EcashBillController>()
                            ?.getTransactions();
                        EasyLoading.dismiss();
                        if (widget.isRoom) {
                          Get.back(result: cashuInfoModel);
                          return;
                        }
                        Get.off(() => CashuTransactionPage(
                            transaction: cashuInfoModel.toCashuTransaction()));
                      } catch (e, s) {
                        String msg = Utils.getErrorMessage(e);
                        if (msg.startsWith('11001')) {
                          await rustCashu.checkProofs();
                          EasyLoading.showError(
                              'Exception: Token already spent. Please retry',
                              duration: const Duration(seconds: 3));
                          return;
                        }
                        EasyLoading.showError(msg,
                            duration: const Duration(seconds: 3));
                        logger.e(msg, error: e, stackTrace: s);
                      }
                    },
                  ))
            ])));
  }
}
