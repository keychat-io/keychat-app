import 'dart:async';

import 'package:app/app.dart';
import 'package:dio/dio.dart';
import 'package:keychat_ecash/Bills/lightning_transaction.dart';
import 'package:keychat_ecash/PayInvoice/PayToLnurl.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:easy_debounce/easy_throttle.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class PayInvoiceController extends GetxController {
  final String? invoice;
  final rust_cashu.InvoiceInfo? invoiceInfo;
  PayInvoiceController({this.invoice, this.invoiceInfo});
  late TextEditingController textController;
  RxString selectedMint = ''.obs;
  RxString selectedInvoice = ''.obs;
  @override
  void onInit() {
    selectedMint.value = Get.find<EcashController>().latestMintUrl.value;
    textController = TextEditingController(text: invoice);
    selectedInvoice.value = invoice ?? '';

    textController.addListener(() {
      EasyThrottle.throttle('invoice', const Duration(milliseconds: 1000),
          () async {
        if (textController.text.trim().isEmpty) {
          return;
        }
        if (textController.text.trim() == selectedInvoice.value) return;
        selectedInvoice.value = textController.text.trim();
        await lnurlPayFirst(selectedInvoice.value);
      });
    });
    super.onInit();
  }

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }

  FutureOr<Transaction?> _confirmPayment(String mint, String invoice,
      rust_cashu.InvoiceInfo ii, bool isPay) async {
    EcashController cc = Get.find<EcashController>();

    if (cc.getBalanceByMint(mint) < ii.amount.toInt()) {
      EasyLoading.showToast('Not Enough Funds');
      return null;
    }
    try {
      EasyLoading.show(status: 'Processing...');
      logger.i(
          'PayInvoiceController: confirmToPayInvoice: mint: $mint, invoice: $invoice');
      Transaction tx =
          await rust_cashu.melt(invoice: invoice, activeMint: mint);
      logger.i('PayInvoiceController: confirmToPayInvoice: tx: ${tx.field0}');
      EasyLoading.showSuccess('Success');

      textController.clear();
      cc.requestPageRefresh();
      if (!isPay) {
        if (GetPlatform.isDesktop) {
          await Get.bottomSheet(LightningTransactionPage(
              transaction: tx.field0 as LNTransaction));
        } else {
          await Get.to(() => LightningTransactionPage(
              transaction: tx.field0 as LNTransaction));
        }
      }
      return tx;
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      EasyLoading.showError('Error: $msg');
      logger.e('error: $msg', error: e, stackTrace: s);
    }
    return null;
  }

  FutureOr<Transaction?> confirmToPayInvoice(
      {required String invoice,
      required String mint,
      bool isPay = false}) async {
    if (invoice.isEmpty) {
      EasyLoading.showToast('Please enter a valid invoice');
      return null;
    }

    if (invoice.startsWith('lightning:')) {
      invoice = invoice.replaceFirst('lightning:', '');
    }
    try {
      rust_cashu.InvoiceInfo ii =
          await rust_cashu.decodeInvoice(encodedInvoice: invoice);

      if (isPay == true) {
        return await _confirmPayment(mint, invoice, ii, isPay);
      }
      return await Get.dialog(CupertinoAlertDialog(
        title: Text('Pay ${ii.amount} ${EcashTokenSymbol.sat.name}'),
        content: Text('''

Expire At: ${DateFormat("yyyy-MM-ddTHH:mm:ss").format(DateTime.fromMillisecondsSinceEpoch(ii.expiryTs.toInt()))}
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
            onPressed: () async {
              Get.back(result: await _confirmPayment(mint, invoice, ii, isPay));
            },
            child: const Text('Confirm'),
          ),
        ],
      ));
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      EasyLoading.showError('Error: $msg');
      logger.e('error: $msg', error: e, stackTrace: s);
    }
    return null;
  }

  FutureOr<Transaction?> lnurlPayFirst(String input) async {
    if (input.isEmpty) {
      return null;
    }
    String? host;
    Map<String, dynamic>? data;

    //demo: npub1g4gxqje4cgrlnjzyz4xk69c2zszaujjjkpwjwq84fh2aeax0avhszurc9m@npub.cash
    if (isEmail(input)) {
      final parts = input.split('@');
      if (parts.length == 2) {
        host = 'https://${parts[1]}/.well-known/lnurlp/${parts[0]}';
        try {
          var res = await Dio().get(host);
          data = res.data;
          data?['domain'] = parts[1];
        } catch (e, s) {
          logger.e('error: $e', error: e, stackTrace: s);
          return null;
        }
      }
    } else if (input.toLowerCase().startsWith('lnurl1')) {
      //demo: LNURL1DP68GURN8GHJ7UM9WFMXJCM99E3K7MF0V9CXJ0M385EKVCENXC6R2C35XVUKXEFCV5MKVV34X5EKZD3EV56NYD3HXQURZEPEXEJXXEPNXSCRVWFNV9NXZCN9XQ6XYEFHVGCXXCMYXYMNSERXFQ5FNS
      String url = rust_nostr.decodeBech32(content: input);
      try {
        var res = await Dio().get(url);
        data = res.data;
        data?['domain'] = Uri.parse(url).host;
      } catch (e, s) {
        logger.e('error: $e', error: e, stackTrace: s);
        return null;
      }
    }

    if (host == null || data == null) {
      return null;
    }

    if (data['tag'] == 'payRequest') {
      if (data['maxSendable'] == null) return null;
      logger.d('LNURL pay request received from: $host , $data');
      if (Get.isBottomSheetOpen ?? false) {
        return null;
      }
      return await Get.bottomSheet<Transaction>(
          ignoreSafeArea: false, PayToLnurl(data));
    }
    return null;
  }
}
