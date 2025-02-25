import 'package:app/app.dart';
import 'package:flutter/material.dart';
import 'package:keychat_ecash/Bills/lightning_transaction.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:intl/intl.dart' show DateFormat;
import 'package:dio/dio.dart' show Dio, DioException;
import 'package:easy_debounce/easy_throttle.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class PayInvoiceController extends GetxController {
  final String? invoice;
  final InvoiceInfo? invoiceInfo;
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
      EasyThrottle.throttle('invoice', const Duration(milliseconds: 300),
          () async {
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

  Future confirmToPayInvoice(
      {required String invoice,
      required String mint,
      bool isPay = false}) async {
    if (invoice.isEmpty) {
      EasyLoading.showToast('Please enter a valid invoice');
      return;
    }

    if (invoice.startsWith('lightning:')) {
      invoice = invoice.replaceFirst('lightning:', '');
    }
    try {
      EcashController cc = Get.find<EcashController>();
      InvoiceInfo ii = await rust_cashu.decodeInvoice(encodedInvoice: invoice);
      Future confirmPayment() async {
        if (cc.getBalanceByMint(mint) < ii.amount.toInt()) {
          EasyLoading.showToast('Not Enough Funds');
          return;
        }
        try {
          EasyLoading.show(status: 'Proccess...');
          var tx = await rust_cashu.melt(invoice: invoice, activeMint: mint);
          EasyLoading.showSuccess('Success');
          if (isPay == false) {
            Get.back(); // close dialog
          }
          textController.clear();
          cc.requestPageRefresh();

          await Get.off(() => LightningTransactionPage(
              transaction: tx.field0 as LNTransaction));
          if (Get.isBottomSheetOpen ?? false) {
            Get.back();
          }
        } catch (e, s) {
          String msg = Utils.getErrorMessage(e);
          EasyLoading.showError('Error: $msg');
          logger.e('error: $msg', error: e, stackTrace: s);
        }
      }

      if (isPay == true) {
        await confirmPayment();
        return;
      }
      await Get.dialog(CupertinoAlertDialog(
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
            onPressed: confirmPayment,
            child: const Text('Confirm'),
          ),
        ],
      ));
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      EasyLoading.showError('Error: $msg');
      logger.e('error: $msg', error: e, stackTrace: s);
    }
  }

  Future<Map<String, dynamic>?> lnurlPayFirst(String input) async {
    if (input.isEmpty) {
      return null;
    }
    String? host;
    Map<String, dynamic>? data;

    if (isEmail(input)) {
      final parts = input.split('@');
      if (parts.length == 2) {
        host = 'https://${parts[1]}/.well-known/lnurlp/${parts[0]}';
        try {
          var res = await Dio().get(host);
          data = res.data;
          data!['domain'] = parts[1];
        } catch (e, s) {
          logger.e('error: $e', error: e, stackTrace: s);
          return null;
        }
      }
    } else if (input.toLowerCase().startsWith('lnurl1')) {
      // final decoded = Bech32Decoder().convert(input);
      // host = utf8.decode(decoded);
      // final resp = await http.get(Uri.parse(host));
      // if (resp.statusCode == 200) {
      //   data = jsonDecode(resp.body);
      // }
    }

    if (host == null || data == null) {
      return null;
    }

    if (data['tag'] == 'payRequest') {
      if (data['maxSendable'] == null) return null;
      logger.d('LNURL pay request received from: $host , $data');
      if (data['maxSendable'] == data['minSendable']) {
        final defaultAmount = data['maxSendable'] / 1000;
        data['defaultAmount'] = defaultAmount;
      }
      if (Get.isBottomSheetOpen ?? false) {
        return null;
      }
      bool isLoading = false;
      final TextEditingController amountController = TextEditingController();
      Get.bottomSheet(
        StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
                body: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        '${data!['domain']} is requesting ${(data['minSendable'] / 1000).round()} and ${(data['maxSendable'] / 1000).round()} sat',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Input Amount(Sats)'),
                    ),
                    Expanded(child: Container()),
                    FilledButton(
                        onPressed: () async {
                          if (isLoading) return;
                          setState(() => isLoading = true);
                          String? pr;
                          try {
                            if (amountController.text.trim().isEmpty) {
                              EasyLoading.showToast(
                                  'Amount must be greater than ${(data!['minSendable'] / 1000).round()}');
                              return;
                            }
                            var amount =
                                int.parse(amountController.text.trim());
                            if (amount == 0) {
                              EasyLoading.showToast(
                                  'Amount must be greater than ${(data!['minSendable'] / 1000).round()}');
                              return;
                            }
                            if (data!['callback'] == null) return;
                            String url =
                                data['callback'] + '?amount=${amount * 1000}';
                            logger.d(url);
                            var res = await Dio().get(url);
                            pr = res.data['pr'];
                            if (pr == null) {
                              EasyLoading.showToast(
                                  'Error: get invoice failed');
                              return;
                            }
                            await confirmToPayInvoice(
                                invoice: pr,
                                mint: selectedMint.value,
                                isPay: true);
                            Get.back();
                          } on DioException catch (e, s) {
                            EasyLoading.showError(
                                e.response?.toString() ?? e.toString());
                            logger.e(
                                'initNofityConfig ${e.response?.toString()}',
                                error: e,
                                stackTrace: s);
                          } catch (e, s) {
                            logger.e('error: ${e.toString()}',
                                error: e, stackTrace: s);
                            EasyLoading.showError('Error: ${e.toString()}');
                            return;
                          } finally {
                            setState(() => isLoading = false);
                          }
                        },
                        style: ButtonStyle(
                            minimumSize: WidgetStateProperty.all(
                                Size(Get.width - 32, 48))),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Pay')),
                  ],
                ),
              ),
            ));
          },
        ),
      );
      return data;
    }
    return null;
  }
}
