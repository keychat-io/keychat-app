import 'package:keychat_ecash/Bills/ecash_bill_controller.dart';
import 'package:keychat_ecash/Bills/lightning_bill_controller.dart';
import 'package:keychat_ecash/Bills/lightning_transaction.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rustCashu;

import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class PayInvoiceController extends GetxController {
  late TextEditingController textController;

  RxString selectedMint = ''.obs;
  @override
  void onInit() {
    selectedMint.value = Get.find<EcashController>().latestMintUrl.value;
    textController = TextEditingController();
    super.onInit();
  }

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }

  void confirm(String mint) async {
    String invoice = textController.text.trim();
    if (invoice.isEmpty) {
      EasyLoading.showToast('Please enter a valid invoice');
      return;
    }
    try {
      EcashController cc = Get.find<EcashController>();
      InvoiceInfo ii = await rustCashu.decodeInvoice(encodedInvoice: invoice);
      Get.dialog(CupertinoAlertDialog(
        title: Text('Pay ${ii.amount} ${EcashTokenSymbol.sat.name}'),
        content: Text('''

Expire At: ${DateTime.fromMillisecondsSinceEpoch(ii.expiryTs.toInt()).toIso8601String()}

Hash: ${ii.hash}
'''),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Get.back();
            },
          ),
          CupertinoDialogAction(
            child: cc.getBalanceByMint(mint) > ii.amount.toInt()
                ? const Text('Confirm')
                : const Text('Not Enough Funds'),
            onPressed: () async {
              if (cc.getBalanceByMint(mint) < ii.amount.toInt()) {
                EasyLoading.showToast('Not Enough Funds');
                return;
              }
              try {
                EasyLoading.show(status: 'Proccess...');
                var tx =
                    await rustCashu.melt(invoice: invoice, activeMint: mint);
                Get.back(); // hide dialog
                textController.clear();
                cc.getBalance();
                Get.find<LightningBillController>().getTransactions();
                Get.find<EcashBillController>().getTransactions();
                EasyLoading.dismiss();
                Get.off(() => LightningTransactionPage(
                    transaction: tx.field0 as LNTransaction));
              } catch (e) {
                EasyLoading.dismiss();
                String msg = Utils.getErrorMessage(e);
                EasyLoading.showError('Error: $msg');
              }
            },
          ),
        ],
      ));
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      EasyLoading.showError('Error: $msg');
      logger.e('error: $msg', error: e, stackTrace: s);
    }
  }
}
