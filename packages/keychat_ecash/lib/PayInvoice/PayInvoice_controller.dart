import 'dart:async';

import 'package:keychat/app.dart';
import 'package:dio/dio.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/Bills/lightning_transaction.dart';
import 'package:keychat_ecash/PayInvoice/PayToLnurl.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/unified_wallet/models/cashu_wallet.dart';
import 'package:keychat_ecash/unified_wallet/models/nwc_wallet.dart';
import 'package:keychat_nwc/nwc/NWC_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:ndk/ndk.dart' show TransactionResult;
import 'package:keychat_nwc/nwc/nwc_transaction_page.dart';

class PayInvoiceController extends GetxController {
  PayInvoiceController({this.invoice, this.invoiceInfo});
  final String? invoice;
  final rust_cashu.InvoiceInfo? invoiceInfo;
  late TextEditingController textController;
  RxString selectedInvoice = ''.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
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

  FutureOr<CashuWalletTransaction?> _payWithCashu(
    String mint,
    String invoice,
    rust_cashu.InvoiceInfo ii,
    bool isPay,
  ) async {
    final cc = Get.find<EcashController>();

    if (cc.getBalanceByMint(mint) < ii.amount.toInt()) {
      await EasyLoading.showToast('Not Enough Funds');
      return null;
    }
    try {
      EasyLoading.show(status: 'Processing...');
      final tx = await rust_cashu.melt(invoice: invoice, activeMint: mint);
      logger.i('PayInvoiceController: confirmToPayInvoice: tx: $tx');
      EasyLoading.showSuccess('Success');

      textController.clear();
      unawaited(cc.requestPageRefresh());
      if (!isPay) {
        if (GetPlatform.isDesktop) {
          await Get.bottomSheet<void>(
            LightningTransactionPage(transaction: tx),
          );
        } else {
          await Get.to<void>(() => LightningTransactionPage(transaction: tx));
        }
      }
      return CashuWalletTransaction(transaction: tx, walletId: mint);
    } catch (e, s) {
      final msg = await EcashUtils.ecashErrorHandle(e, s);
      EasyLoading.showError(msg);
    }
    return null;
  }

  FutureOr<NwcWalletTransaction?> _payWithNwc(
    String nwcUri,
    String invoice,
    rust_cashu.InvoiceInfo ii,
    bool isPay,
  ) async {
    final nwcController =
        Utils.getOrPutGetxController(create: NwcController.new);

    try {
      EasyLoading.show(status: 'Processing...');

      // Use NWC to pay invoice
      final active = nwcController.activeConnections.firstWhereOrNull(
        (c) => c.info.uri == nwcUri,
      );

      if (active == null) {
        EasyLoading.showError('NWC connection not found');
        return null;
      }

      // Check balance
      if (active.balance != null) {
        final balanceSat = (active.balance!.balanceMsats / 1000).floor();
        if (balanceSat < ii.amount.toInt()) {
          EasyLoading.showError('Not Enough Funds');
          return null;
        }
      }

      // Pay invoice through NWC
      final ndk = nwcController.ndk;
      final result =
          await ndk.nwc.payInvoice(active.connection, invoice: invoice);

      logger.i('PayInvoiceController: NWC payment successful');
      EasyLoading.showSuccess('Success');

      textController.clear();

      // Refresh NWC balance
      await nwcController.refreshBalances([active]);

      final tx = NwcWalletTransaction(
        transaction: TransactionResult(
          type: 'outgoing',
          invoice: invoice,
          amount: ii.amount.toInt() * 1000,
          description: ii.memo,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          feesPaid: result.feesPaid ~/ 1000,
          preimage: result.preimage,
          paymentHash: 'none',
        ),
        walletId: nwcUri,
      );
      return tx;
    } catch (e, s) {
      logger.e('NWC payment error', error: e, stackTrace: s);
      await EasyLoading.showError('Payment Failed: $e');
    } finally {
      Future<void>.delayed(const Duration(seconds: 2)).then((value) async {
        await EasyLoading.dismiss();
      });
    }
    return null;
  }

  /// Pay a lightning invoice and return the payment result.
  /// Returns [CashuWalletTransaction] for Cashu payments or [NwcWalletTransaction] for NWC payments.
  FutureOr<WalletTransactionBase?> confirmToPayInvoice({
    required String invoice,
    required WalletBase walletSelection,
    bool isPay = false, // pay invoice, then return
  }) async {
    if (invoice.isEmpty) {
      await EasyLoading.showToast('Please enter a valid invoice');
      return null;
    }

    if (invoice.startsWith('lightning:')) {
      invoice = invoice.replaceFirst('lightning:', '');
    }
    try {
      final ii = await rust_cashu.decodeInvoice(encodedInvoice: invoice);

      // Handle NWC payment
      if (walletSelection.protocol == WalletProtocol.nwc) {
        if (isPay) {
          return await _payWithNwc(
            walletSelection.id,
            invoice,
            ii,
            isPay,
          );
        }
        return await Get.dialog<NwcWalletTransaction?>(
          CupertinoAlertDialog(
            title: const Text('Pay Invoice'),
            content: Text(
              '${ii.amount} ${EcashTokenSymbol.sat.name}',
              style: Theme.of(Get.context!).textTheme.titleLarge,
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Get.back<NwcWalletTransaction?>(),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  Get.back<void>(); // close dialog
                  final res = await _payWithNwc(
                    walletSelection.id,
                    invoice,
                    ii,
                    isPay,
                  );
                  if (res == null) return;
                  if (Get.isBottomSheetOpen ?? false) {
                    Get.back<void>(); // close bottom sheet
                  }
                  await Get.to<void>(
                    () => NwcTransactionPage(
                      transaction: res.rawData,
                      nwcUri: walletSelection.id,
                    ),
                    id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
                  );
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      }

      // Handle Cashu payment
      if (isPay) {
        return await _payWithCashu(
          walletSelection.id,
          invoice,
          ii,
          isPay,
        );
      }
      return await Get.dialog<CashuWalletTransaction?>(
        CupertinoAlertDialog(
          title: const Text('Pay Invoice'),
          content: Text(
            '${ii.amount} ${EcashTokenSymbol.sat.name}',
            style: Theme.of(Get.context!).textTheme.titleLarge,
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Get.back<CashuWalletTransaction?>(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                Get.back(
                  result: await _payWithCashu(
                    walletSelection.id,
                    invoice,
                    ii,
                    isPay,
                  ),
                );
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
      EasyLoading.showError('Error: $msg');
      logger.e('error: $msg', error: e, stackTrace: s);
    }
    return null;
  }

  FutureOr<WalletTransactionBase?> lnurlPayFirst(String input) async {
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
          final res = await Dio().get<dynamic>(host);
          data = res.data as Map<String, dynamic>?;
          data?['domain'] = parts[1];
        } catch (e, s) {
          final errorMessage =
              '${(e as DioException).response?.data ?? e.message}';
          logger.e('error: $errorMessage', error: e, stackTrace: s);
          EasyLoading.showError(
            'Could not get lightning address details from the server: $errorMessage',
            duration: const Duration(seconds: 4),
          );
          return null;
        }
      }
    } else if (input.toLowerCase().startsWith('lnurl1')) {
      //demo: LNURL1DP68GURN8GHJ7UM9WFMXJCM99E3K7MF0V9CXJ0M385EKVCENXC6R2C35XVUKXEFCV5MKVV34X5EKZD3EV56NYD3HXQURZEPEXEJXXEPNXSCRVWFNV9NXZCN9XQ6XYEFHVGCXXCMYXYMNSERXFQ5FNS
      final url = rust_nostr.decodeBech32(content: input);
      try {
        final res = await Dio().get<dynamic>(url);
        data = res.data as Map<String, dynamic>?;
        data?['domain'] = Uri.parse(url).host;
      } catch (e, s) {
        final errorMessage =
            '${(e as DioException).response?.data ?? e.message}';
        logger.e('error: $errorMessage', error: e, stackTrace: s);
        EasyLoading.showError(
          'Could not get lightning address details from the server: $errorMessage',
          duration: const Duration(seconds: 4),
        );
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
        Get.back<void>();
      }
      return await Get.bottomSheet<WalletTransactionBase?>(
        ignoreSafeArea: false,
        PayToLnurl(data, input),
      );
    }
    final errorMessage =
        (data['reason'] as String?) ?? 'Unable to find valid user walle';
    throw Exception(errorMessage);
  }
}
