import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:keychat/service/qrscan.service.dart';
import 'package:keychat/app.dart';
import 'package:keychat_nwc/active_nwc_connection.dart';
import 'package:keychat_nwc/nwc.service.dart';
import 'package:ndk/ndk.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:keychat_nwc/nwc/nwc_transaction_page.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

class NwcController extends GetxController {
  final NwcService _nwcService = NwcService.instance;

  final RxList<ActiveNwcConnection> activeConnections =
      <ActiveNwcConnection>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    isLoading.value = true;
    try {
      await _nwcService.init();
      refreshList();
    } finally {
      isLoading.value = false;
    }
    // Fetch balances in background
    refreshBalances();
    fetchTransactionsForCurrent();
  }

  void refreshList() {
    activeConnections.value = _nwcService.activeConnections;
    logger.i('Loaded ${activeConnections.length} NWC connections');
  }

  Future<void> refreshBalances() async {
    for (final connection in activeConnections) {
      try {
        await _nwcService.refreshBalance(connection.info.uri);
        activeConnections.refresh(); // Update UI for this specific connection
      } catch (e) {
        // Log error but continue
        logger.e('Error refreshing balance for ${connection.info.uri}: $e');
      }
    }
  }

  Future<void> addConnection(String uri) async {
    try {
      isLoading.value = true;
      await _nwcService.add(uri);
      refreshList();
      Get.back(); // Close dialog
      Get.snackbar('Success', 'NWC Connection added');
    } catch (e, s) {
      logger.e(e, stackTrace: s);
      EasyLoading.showError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteConnection(String uri) async {
    try {
      isLoading.value = true;
      await _nwcService.remove(uri);
      refreshList();
      Get.back(); // Close settings page or dialog
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete connection: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> payInvoice(String invoice) async {
    if (invoice.isEmpty) {
      await Get.bottomSheet(
        CupertinoActionSheet(
          title: const Text('Pay Invoice'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                Get.back();
                final scanned = await QrScanService.instance.handleQRScan(
                  autoProcess: false,
                );
                if (scanned != null && scanned.isNotEmpty) {
                  payInvoice(scanned);
                }
              },
              child: const Text('Scan QR Code'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Get.back();
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null && data!.text!.isNotEmpty) {
                  payInvoice(data.text!);
                } else {
                  EasyLoading.showError('Clipboard is empty');
                }
              },
              child: const Text('Paste from Clipboard'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: Get.back,
            child: const Text('Cancel'),
          ),
        ),
      );
      return;
    }

    if (activeConnections.isEmpty) {
      EasyLoading.showError('No NWC connection available');
      return;
    }

    // Basic validation
    if (!invoice.toLowerCase().startsWith('ln')) {
      EasyLoading.showError('Invalid Lightning Invoice');
      return;
    }

    // Decode Invoice
    rust_cashu.InvoiceInfo? invoiceInfo;
    try {
      EasyLoading.show(status: 'Decoding...');
      invoiceInfo = await rust_cashu.decodeInvoice(encodedInvoice: invoice);
      EasyLoading.dismiss();
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('Invalid Invoice: $e');
      return;
    }

    // Show Confirmation Dialog
    final confirmed = await Get.dialog<bool>(
      CupertinoAlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              '${invoiceInfo.amount} sats',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (invoiceInfo.memo != null && invoiceInfo.memo!.isNotEmpty)
              Text('Memo: ${invoiceInfo.memo}'),
            const SizedBox(height: 5),
            Text(
              'Expiry: ${DateTime.fromMillisecondsSinceEpoch(invoiceInfo.expiryTs.toInt())}',
              style: const TextStyle(
                fontSize: 10,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Get.back(result: false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Pay'),
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );
    logger.i('Payment confirmed: $confirmed, invoice: $invoice');
    if (confirmed != true) return;

    var index = currentIndex.value;
    if (index < 0 || index >= activeConnections.length) {
      index = 0;
    }
    final connection = activeConnections[index];
    final uri = connection.info.uri;

    try {
      EasyLoading.show(status: 'Paying...');
      await _nwcService.payInvoice(uri, invoice);
      EasyLoading.showSuccess('Payment Successful');

      // Refresh data
      await refreshBalances();
      await fetchTransactionsForCurrent();
    } catch (e) {
      EasyLoading.showError('Payment Failed: $e');
    }
  }

  Future<void> receive() async {
    if (activeConnections.isEmpty) {
      EasyLoading.showError('No NWC connection available');
      return;
    }

    final amountController = TextEditingController();
    final descController = TextEditingController();

    await Get.dialog(
      CupertinoAlertDialog(
        title: const Text('Receive Sats'),
        content: Column(
          children: [
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: amountController,
              placeholder: 'Amount (sats)',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: descController,
              placeholder: 'Description (optional)',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: Get.back,
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Create Invoice'),
            onPressed: () async {
              if (amountController.text.isEmpty) return;
              final amount = int.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                EasyLoading.showError('Invalid amount');
                return;
              }
              Get.back();
              await _createAndShowInvoice(amount, descController.text);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _createAndShowInvoice(int amount, String? description) async {
    var index = currentIndex.value;
    if (index < 0 || index >= activeConnections.length) {
      index = 0;
    }
    final connection = activeConnections[index];
    final uri = connection.info.uri;

    try {
      EasyLoading.show(status: 'Creating Invoice...');
      final response = await _nwcService.makeInvoice(
        uri,
        amountSats: amount,
        description: description,
      );
      EasyLoading.dismiss();

      if (response == null) {
        EasyLoading.showError('Failed to create invoice');
        return;
      }

      final tx = TransactionResult(
        type: 'incoming',
        invoice: response.invoice,
        amount: response.amountSat * 1000,
        description: response.description,
        createdAt: response.createdAt,
        feesPaid: response.feesPaid,
        paymentHash: response.paymentHash,
        preimage: response.preimage,
      );

      Get.to(
        () => NwcTransactionPage(
          transaction: tx,
          nwcUri: uri,
        ),
      );
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('Error: $e');
    }
  }

  final RxInt currentIndex = 0.obs;

  void updateCurrentIndex(int index) {
    if (index >= 0 && index < activeConnections.length) {
      currentIndex.value = index;
      fetchTransactionsForCurrent();
    }
  }

  Future<void> fetchTransactionsForCurrent() async {
    if (activeConnections.isEmpty) return;
    if (currentIndex.value >= activeConnections.length) return;

    final uri = activeConnections[currentIndex.value].info.uri;
    try {
      await listTransactions(uri, limit: 10); // Default limit
      refreshList(); // Update UI to show transactions
    } catch (e) {
      // Silent fail or log?
      print('Error fetching transactions: $e');
    }
  }

  Future<ListTransactionsResponse?> listTransactions(
    String uri, {
    int? limit,
    int? offset,
  }) async {
    try {
      return await _nwcService.listTransactions(
        uri,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to list transactions: $e');
      return null;
    }
  }

  Future<MakeInvoiceResponse?> makeInvoice(
    String uri,
    int amountSats, {
    String? description,
  }) async {
    try {
      return await _nwcService.makeInvoice(
        uri,
        amountSats: amountSats,
        description: description,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to make invoice: $e');
      return null;
    }
  }

  Future<LookupInvoiceResponse?> lookupInvoice(
    String uri, {
    String? invoice,
  }) async {
    try {
      return await _nwcService.lookupInvoice(uri, invoice: invoice);
    } catch (e) {
      Get.snackbar('Error', 'Failed to lookup invoice: $e');
      return null;
    }
  }
}
