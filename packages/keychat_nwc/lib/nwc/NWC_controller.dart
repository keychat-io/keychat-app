import 'dart:async';
import 'dart:convert' show jsonEncode;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/service/qrscan.service.dart';
import 'package:keychat_nwc/active_nwc_connection.dart';
import 'package:keychat_nwc/nwc_connection_info.dart';
import 'package:keychat_nwc/nwc_connection_storage.dart';
import 'package:keychat_nwc/nwc/nwc_transaction_page.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart'
    show TransactionStatus;
import 'package:ndk/ndk.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class NwcController extends GetxController {
  late Ndk ndk;
  NwcConnectionStorage _storage = NwcConnectionStorage();
  final Map<String, ActiveNwcConnection> _activeConnections = {};
  final QrScanService qrScanService = QrScanService.instance;

  final RxList<ActiveNwcConnection> activeConnections =
      <ActiveNwcConnection>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;
  final RxInt currentIndex = 0.obs;

  /// Computed total balance across all connections
  int get totalSats {
    return activeConnections.fold<int>(
      0,
      (sum, connection) => sum + (connection.balance?.balanceSats ?? 0),
    );
  }

  /// Inject storage for testing
  set storage(NwcConnectionStorage storage) => _storage = storage;

  @override
  void onInit() {
    super.onInit();
    _loadConnections();
  }

  /// Wait for isLoading to become true, with a maximum timeout of 5 seconds
  /// Returns true if isLoading became true, false if timeout
  Future<bool> waitForLoading() async {
    if (isInitialized.value) {
      return true;
    }

    final completer = Completer<bool>();
    late Worker worker;
    Timer? timeoutTimer;

    worker = ever(isInitialized, (bool value) {
      if (value && !completer.isCompleted) {
        timeoutTimer?.cancel();
        worker.dispose();
        completer.complete(true);
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        worker.dispose();
        completer.complete(false);
      }
    });

    return completer.future;
  }

  Future<void> _loadConnections() async {
    isLoading.value = true;
    try {
      await _initNdk();
      final savedConnections = await _storage.getAll();
      for (final info in savedConnections) {
        await _connectAndAdd(info);
      }
      refreshList();
      // Fetch balances in background
      await refreshBalances();
    } finally {
      isLoading.value = false;
      isInitialized.value = true;
    }
  }

  Future<void> _initNdk({EventVerifier? eventVerifier}) async {
    ndk = Ndk(
      NdkConfig(
        eventVerifier: eventVerifier ?? RustEventVerifier(),
        cache: MemCacheManager(),
        logLevel: kDebugMode ? LogLevel.debug : LogLevel.error,
      ),
    );
  }

  Future<void> _connectAndAdd(NwcConnectionInfo info) async {
    try {
      final connection = await ndk.nwc.connect(info.uri);

      logger.i(
        "waiting for ${connection.isLegacyNotifications() ? "legacy " : ""}notifications for ${info.uri}",
      );
      connection.notificationStream.stream.listen((notification) {
        logger.i(
          'notification ${notification.type} amount: ${notification.amount}',
        );
      });

      final active = ActiveNwcConnection(info: info, connection: connection);
      _activeConnections[info.uri] = active;
    } catch (e) {
      logger.e('Failed to connect to NWC: ${info.uri} error: $e');
    }
  }

  void refreshList() {
    activeConnections.value = _activeConnections.values.toList();
    logger.i('Loaded ${activeConnections.length} NWC connections');
  }

  Future<void> refreshBalances([List<ActiveNwcConnection>? connections]) async {
    isLoading.value = true;
    try {
      for (final connection in connections ?? activeConnections) {
        try {
          await _refreshBalance(connection.info.uri);
          activeConnections.refresh(); // Update UI for this specific connection
        } catch (e) {
          logger.e('Error refreshing balance for ${connection.info.uri}: $e');
        }
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<GetBalanceResponse?> getBalance(String nwcUri) async {
    final active = _activeConnections[nwcUri];
    if (active == null) {
      throw Exception('NWC Connection not found: $nwcUri');
    }

    if (active.balance != null) {
      return active.balance;
    }

    return _refreshBalance(nwcUri);
  }

  Future<GetBalanceResponse> _refreshBalance(String nwcUri) async {
    final active = _activeConnections[nwcUri];
    if (active == null) {
      throw Exception('NWC Connection not found: $nwcUri');
    }

    final balance = await ndk.nwc.getBalance(active.connection);
    active.balance = balance;
    return balance;
  }

  Future<void> refreshAllBalances() async {
    for (final uri in _activeConnections.keys) {
      try {
        await _refreshBalance(uri);
      } catch (e) {
        logger.e('Failed to refresh balance for $uri: $e');
      }
    }
  }

  /// Reload connections by reconnecting NDK and re-executing _loadConnections
  Future<void> reloadConnections() async {
    isLoading.value = true;
    isInitialized.value = false;
    try {
      await ndk.destroy();
      // Clear existing connections
      _activeConnections.clear();
      activeConnections.clear();

      // Reinitialize NDK and load connections
      await _loadConnections();
      // fetchTransactionsForCurrent();
    } catch (e) {
      logger.e('Failed to reload connections: $e');
      EasyLoading.showError('Failed to reload connections');
    } finally {
      isLoading.value = false;
      isInitialized.value = true;
    }
  }

  Future<void> addConnection(String uri) async {
    try {
      isLoading.value = true;

      // Check if already exists
      if (_activeConnections.containsKey(uri)) {
        throw Exception('Connection already active');
      }

      final info = NwcConnectionInfo(uri: uri);
      await _storage.add(info);
      await _connectAndAdd(info);
      refreshList();
      await EasyLoading.showSuccess('NWC Connection added');
      if (Get.isDialogOpen ?? false) {
        Get.back(); // Close dialog
      }
    } catch (e, s) {
      logger.e(e, stackTrace: s);
      EasyLoading.showError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateConnectionName(String uri, String newName) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('Connection not found');
      }

      final updatedInfo = NwcConnectionInfo(
        uri: uri,
        name: newName.isEmpty ? null : newName,
        weight: active.info.weight,
      );

      await _storage.update(updatedInfo);
      active.info = updatedInfo;
      refreshList();
      await EasyLoading.showSuccess('Connection name updated');
    } catch (e) {
      await EasyLoading.showError('Failed to update name: $e');
    }
  }

  Future<void> deleteConnection(String uri) async {
    try {
      isLoading.value = true;
      await _storage.delete(uri);
      _activeConnections.remove(uri);
      refreshList();
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete connection: $e');
    } finally {
      isLoading.value = false;
    }
  }

  @Deprecated("Use PayInvoiceController' s confirmToPayInvoice instead")
  Future<void> payInvoice(String invoice) async {
    if (invoice.isEmpty) {
      await Get.bottomSheet(
        CupertinoActionSheet(
          title: const Text('Pay Invoice'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                Get.back();
                final scanned = await QrScanService.instance.handleQRScan();
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
    if (invoice.startsWith('lightning:')) {
      invoice = invoice.replaceFirst('lightning:', '');
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
              '${invoiceInfo.amount} sat',
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

      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('NWC Connection not found: $uri');
      }

      await ndk.nwc.payInvoice(active.connection, invoice: invoice);
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
              placeholder: 'Amount (sat)',
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

      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('NWC Connection not found: $uri');
      }

      final response = await ndk.nwc.makeInvoice(
        active.connection,
        amountSats: amount,
        description: description,
      );
      EasyLoading.dismiss();

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
      logger.e('Error fetching transactions: $e');
    }
  }

  Future<ListTransactionsResponse?> listTransactions(
    String uri, {
    int? from,
    int? until,
    int? limit,
    int? offset,
    bool unpaid = true,
  }) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('NWC Connection not found: $uri');
      }

      final response = await ndk.nwc.listTransactions(
        active.connection,
        from: from,
        until: until,
        limit: limit,
        offset: offset,
        unpaid: unpaid,
      );
      active.transactions = response;
      return response;
    } catch (e) {
      Get.snackbar('Error', 'Failed to list transactions: $e');
      return null;
    }
  }

  Future<MakeInvoiceResponse?> makeInvoice(
    String uri,
    int amountSats, {
    String? description,
    String? descriptionHash,
    int? expiry,
  }) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('NWC Connection not found: $uri');
      }

      return await ndk.nwc.makeInvoice(
        active.connection,
        amountSats: amountSats,
        description: description,
        descriptionHash: descriptionHash,
        expiry: expiry,
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
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('NWC Connection not found: $uri');
      }

      return await ndk.nwc.lookupInvoice(active.connection, invoice: invoice);
    } catch (e) {
      Get.snackbar('Error', 'Failed to lookup invoice: $e');
      return null;
    }
  }

  Future<GetInfoResponse?> getInfo(String uri) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('NWC Connection not found: $uri');
      }

      return await ndk.nwc.getInfo(active.connection);
    } catch (e) {
      Get.snackbar('Error', 'Failed to get info: $e');
      return null;
    }
  }

  TransactionStatus getTransactionStatus(TransactionResult transaction) {
    if (transaction.preimage != null && transaction.preimage!.isNotEmpty) {
      return TransactionStatus.success;
    }
    if (transaction.expiresAt != null && transaction.expiresAt! > 0) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        transaction.expiresAt! * 1000,
      );
      if (DateTime.now().isAfter(expiry)) {
        return TransactionStatus.expired;
      }
    }
    return TransactionStatus.pending;
  }
}

class RustEventVerifier implements EventVerifier {
  @override
  Future<bool> verify(Nip01Event event) async {
    try {
      await rust_nostr.verifyEvent(json: jsonEncode(event.toJson()));
      return true;
    } catch (e, s) {
      logger.e(
        'Event verification failed: ${event.toJson()} , $e',
        stackTrace: s,
      );
      return false;
    }
  }
}
