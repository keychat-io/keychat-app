import 'package:keychat_ecash/Bills/lightning_transaction.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:intl/intl.dart' show DateFormat;

import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class PayInvoiceController extends GetxController {
  String? invoice;
  PayInvoiceController([this.invoice]);
  late TextEditingController textController;

  RxString selectedMint = ''.obs;
  @override
  void onInit() {
    selectedMint.value = Get.find<EcashController>().latestMintUrl.value;
    textController = TextEditingController(text: invoice);
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
      InvoiceInfo ii = await rust_cashu.decodeInvoice(encodedInvoice: invoice);
      Get.dialog(CupertinoAlertDialog(
        title: Text('Pay ${ii.amount} ${EcashTokenSymbol.sat.name}'),
        content: Text('''

Expire At: ${DateFormat("yyyy-MM-ddTHH:mm:ss").format(DateTime.fromMillisecondsSinceEpoch(ii.expiryTs.toInt()))}

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
            isDefaultAction: true,
            child: const Text('Confirm'),
            onPressed: () async {
              if (cc.getBalanceByMint(mint) < ii.amount.toInt()) {
                EasyLoading.showToast('Not Enough Funds');
                return;
              }
              try {
                EasyLoading.show(status: 'Proccess...');
                var tx =
                    await rust_cashu.melt(invoice: invoice, activeMint: mint);
                EasyLoading.showSuccess('Success');
                Get.back();
                textController.clear();
                cc.requestPageRefresh();
                Get.off(() => LightningTransactionPage(
                    transaction: tx.field0 as LNTransaction));
              } catch (e, s) {
                String msg = Utils.getErrorMessage(e);
                EasyLoading.showError('Error: $msg');
                logger.e('error: $msg', error: e, stackTrace: s);
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
