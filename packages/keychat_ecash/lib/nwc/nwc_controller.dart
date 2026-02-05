import 'dart:async';

import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat_ecash/nwc/index.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart'
    show TransactionStatus;

/// Controller for managing NWC (Nostr Wallet Connect) connections.
class NwcController extends GetxController {
  NwcConnectionStorage _storage = NwcConnectionStorage();
  final Map<String, ActiveNwcConnection> _activeConnections = {};

  final RxList<ActiveNwcConnection> activeConnections =
      <ActiveNwcConnection>[].obs;
  final RxBool isInitialized = false.obs;
  final RxInt currentIndex = 0.obs;

  /// Flag to indicate if any NWC connection has failed due to permission error.
  final RxBool hasFailedConnection = false.obs;

  /// Computed total balance across all connections.
  int get totalSats {
    return activeConnections.fold<int>(
      0,
      (sum, connection) => sum + (connection.balance?.balanceSats ?? 0),
    );
  }

  /// Inject storage for testing.
  set storage(NwcConnectionStorage storage) => _storage = storage;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadConnections();
  }

  @override
  void onClose() {
    // Close all NWC client connections
    for (final connection in _activeConnections.values) {
      connection.client.close();
    }
    super.onClose();
  }

  /// Wait for isLoading to become true, with a maximum timeout of 10 seconds.
  /// Returns true if isLoading became true, false if timeout.
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
    try {
      final savedConnections = await _storage.getAll();
      for (final info in savedConnections) {
        await _connectAndAdd(info);
      }
      refreshList();
      // Fetch balances in background
      await refreshNwcBalances();
    } finally {
      isInitialized.value = true;
    }
  }

  Future<void> _connectAndAdd(NwcConnectionInfo info) async {
    try {
      final client = await NwcClient.fromUri(info.uri);

      // Subscribe to responses
      client.subscribe();

      logger.i('NWC client connected for ${info.uri}');

      final active = ActiveNwcConnection(info: info, client: client);
      _activeConnections[info.uri] = active;
    } catch (e) {
      logger.e('Failed to connect to NWC: ${info.uri} error: $e');
    }
  }

  void refreshList() {
    activeConnections.value = _activeConnections.values.toList();
    logger.i('Loaded ${activeConnections.length} NWC connections');
  }

  Future<void> refreshNwcBalances([
    List<ActiveNwcConnection>? connections,
  ]) async {
    for (final connection in connections ?? activeConnections) {
      try {
        await _refreshBalance(connection.info.uri);
      } catch (e) {
        logger.e('Error refreshing balance for ${connection.info.uri}: $e');
        EasyThrottle.throttle('refreshNwcBalances', const Duration(seconds: 5),
            () async {
          // Check if error is permission-related
          if (e.toString().toLowerCase().contains('not in permissions')) {
            hasFailedConnection.value = true;
          }
        });
      }
    }
    // Update UI after all balances are refreshed
    activeConnections.refresh();
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

    final balance = await active.client.getBalance();
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

  /// Reload connections by reconnecting all clients.
  Future<void> reloadConnections() async {
    isInitialized.value = false;
    try {
      // Close existing connections
      for (final connection in _activeConnections.values) {
        connection.client.close();
      }
      _activeConnections.clear();
      activeConnections.clear();
      hasFailedConnection.value = false;

      // Reload connections
      await _loadConnections();
    } catch (e) {
      logger.e('Failed to reload connections: $e');
      await EasyLoading.showError('Failed to reload connections');
    } finally {
      isInitialized.value = true;
    }
  }

  Future<void> addConnection(String uri) async {
    // Check if already exists
    if (_activeConnections.containsKey(uri)) {
      throw Exception('Connection already active');
    }

    final info = NwcConnectionInfo(uri: uri);
    await _storage.add(info);
    await _connectAndAdd(info);
    refreshList();
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
      await EasyLoading.showError(e.toString());
    }
  }

  Future<bool> deleteConnection(String uri) async {
    try {
      // Close the client connection
      final active = _activeConnections[uri];
      if (active != null) {
        active.client.close();
      }

      await _storage.delete(uri);
      _activeConnections.remove(uri);
      refreshList();
    } catch (e) {
      await EasyLoading.showError(e.toString());
      return false;
    }
    return true;
  }

  Future<void> updateCurrentIndex(int index) async {
    if (index >= 0 && index < activeConnections.length) {
      currentIndex.value = index;
      await fetchTransactionsForCurrent();
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

  int reloadConnectionsTimes = 0;

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

      final response = await active.client.listTransactions(
        from: from,
        until: until,
        limit: limit,
        offset: offset,
        unpaid: unpaid,
      );
      active.transactions = response;
      reloadConnectionsTimes = 0;
      return response;
    } catch (e) {
      final msg = e.toString();
      logger.e('nwc listTransactions: $msg');
      if (msg.contains('not in permissions')) {
        EasyThrottle.throttle('not_in_permissions', const Duration(seconds: 5),
            () async {
          if (reloadConnectionsTimes >= 5) return;
          reloadConnectionsTimes++;
          await EasyLoading.showToast('ReConnecting...');
          await reloadConnections();
        });
      }
      return null;
    }
  }

  Future<GetInfoResponse?> getInfo(String uri) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('NWC Connection not found: $uri');
      }

      return await active.client.getInfo();
    } catch (e) {
      await EasyLoading.showError(e.toString());
      return null;
    }
  }

  Future<LookupInvoiceResponse?> lookupInvoice({
    required String uri,
    String? invoice,
    String? paymentHash,
  }) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('NWC Connection not found: $uri');
      }

      await waitForLoading();
      return await active.client.lookupInvoice(
        invoice: invoice,
        paymentHash: paymentHash,
      );
    } catch (e) {
      await EasyLoading.showError(e.toString());
      return null;
    }
  }

  /// Pays a lightning invoice.
  Future<PayInvoiceResponse?> payInvoice({
    required String uri,
    required String invoice,
  }) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('NWC Connection not found: $uri');
      }

      await waitForLoading();
      return await active.client.payInvoice(invoice);
    } catch (e) {
      logger.e('NWC payInvoice error', error: e);
      return null;
    }
  }

  /// Creates a new invoice.
  Future<MakeInvoiceResponse?> makeInvoice({
    required String uri,
    required int amountSats,
    String? description,
  }) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('NWC Connection not found: $uri');
      }

      await waitForLoading();
      return await active.client.makeInvoice(
        amountSats: amountSats,
        description: description,
      );
    } catch (e) {
      logger.e('NWC makeInvoice error', error: e);
      return null;
    }
  }

  /// Gets the active client for a given URI.
  NwcClient? getClient(String uri) {
    return _activeConnections[uri]?.client;
  }

  /// Processes an NWC response event from a relay.
  ///
  /// Routes the response to the appropriate client.
  Future<void> processResponseEvent(Map<String, dynamic> eventData) async {
    final walletPubkey = eventData['pubkey'] as String?;
    if (walletPubkey == null) return;

    // Find the client that matches this wallet pubkey
    for (final connection in _activeConnections.values) {
      if (connection.client.walletPubkey == walletPubkey) {
        await connection.client.processResponseEvent(eventData);
        return;
      }
    }

    logger.d('No NWC client found for wallet pubkey: $walletPubkey');
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
