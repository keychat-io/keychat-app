import 'dart:async';

import 'package:keychat/app.dart';
import 'package:dio/dio.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/PayInvoice/PayToLnurl.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_ecash/unified_wallet/index.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class PayInvoiceController extends GetxController {
  PayInvoiceController({this.invoice, this.invoiceInfo});
  final String? invoice;
  final rust_cashu.InvoiceInfo? invoiceInfo;
  late TextEditingController textController;
  late UnifiedWalletController unifiedWalletController;
  RxString selectedInvoice = ''.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    textController = TextEditingController(text: invoice);
    selectedInvoice.value = invoice ?? '';
    unifiedWalletController = Utils.getOrPutGetxController(
      create: UnifiedWalletController.new,
    );

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

  /// Pay a lightning invoice and return the payment result.
  /// Returns [CashuWalletTransaction] for Cashu payments or [NwcWalletTransaction] for NWC payments.
  FutureOr<WalletTransactionBase?> confirmToPayInvoice({
    required String invoice,
    required WalletBase walletSelection,
    bool isPay = false, // pay invoice directly without confirmation dialog
  }) async {
    if (invoice.isEmpty) {
      await EasyLoading.showToast('Please enter a valid invoice');
      return null;
    }

    if (invoice.startsWith('lightning:')) {
      invoice = invoice.replaceFirst('lightning:', '');
    }

    try {
      // Decode invoice to get amount for confirmation dialog
      final invoiceInfo = await rust_cashu.decodeInvoice(
        encodedInvoice: invoice,
      );

      // If isPay is true, pay directly without confirmation
      if (isPay) {
        final tx = await unifiedWalletController.payLightningInvoiceWithWallet(
          walletSelection.id,
          invoice,
        );
        if (tx != null) {
          textController.clear();
        }
        return tx;
      }

      // Show confirmation dialog before payment
      return await Get.dialog<WalletTransactionBase?>(
        CupertinoAlertDialog(
          title: const Text('Pay Invoice'),
          content: Text(
            '${invoiceInfo.amount} ${EcashTokenSymbol.sat.name}',
            style: Theme.of(Get.context!).textTheme.titleLarge,
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Get.back<WalletTransactionBase?>(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                final tx =
                    await unifiedWalletController.payLightningInvoiceWithWallet(
                  walletSelection.id,
                  invoice,
                );
                if (tx != null) {
                  textController.clear();
                }
                Get.back(result: tx);
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
        isScrollControlled: GetPlatform.isMobile,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        ),
        PayToLnurl(data, input),
      );
    }
    final errorMessage =
        (data['reason'] as String?) ?? 'Unable to find valid user walle';
    throw Exception(errorMessage);
  }
}
