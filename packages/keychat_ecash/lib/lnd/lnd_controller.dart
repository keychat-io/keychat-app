import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat_ecash/lnd/active_lnd_connection.dart';
import 'package:keychat_ecash/lnd/lnd_connection_info.dart';
import 'package:keychat_ecash/lnd/lnd_connection_storage.dart';
import 'package:keychat_ecash/lnd/lnd_rest_client.dart';

/// GetX controller for managing LND wallet connections.
class LndController extends GetxController {
  LndConnectionStorage _storage = LndConnectionStorage();
  final Map<String, ActiveLndConnection> _activeConnections = {};

  final RxList<ActiveLndConnection> activeConnections =
      <ActiveLndConnection>[].obs;
  final RxBool isInitialized = false.obs;
  final RxInt currentIndex = 0.obs;

  /// Flag to indicate if any LND connection has failed
  final RxBool hasFailedConnection = false.obs;

  /// Total balance across all connections (in sats)
  int get totalSats {
    return activeConnections.fold<int>(
      0,
      (sum, connection) =>
          sum + (connection.balance?.spendableBalanceSat ?? 0),
    );
  }

  /// Inject storage for testing
  set storage(LndConnectionStorage storage) => _storage = storage;

  @override
  void onInit() {
    super.onInit();
    _loadConnections();
  }

  @override
  void onClose() {
    // Close all client connections
    for (final connection in _activeConnections.values) {
      connection.close();
    }
    super.onClose();
  }

  /// Wait for initialization to complete with timeout.
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
      _refreshList();
      // Fetch balances in background
      await refreshAllBalances();
    } finally {
      isInitialized.value = true;
    }
  }

  Future<void> _connectAndAdd(LndConnectionInfo info) async {
    try {
      final client = LndRestClient(info);

      // Test connection by fetching node info
      final nodeInfo = await client.getInfo();

      final active = ActiveLndConnection(
        info: info,
        client: client,
        nodeInfo: nodeInfo,
      );
      _activeConnections[info.uri] = active;
    } catch (e) {
      logger.e('Failed to connect to LND: ${info.host}:${info.port} error: $e');
      hasFailedConnection.value = true;
    }
  }

  void _refreshList() {
    activeConnections.value = _activeConnections.values.toList();
    logger.i('Loaded ${activeConnections.length} LND connections');
  }

  /// Refresh balances for all connections.
  Future<void> refreshAllBalances([
    List<ActiveLndConnection>? connections,
  ]) async {
    for (final connection in connections ?? activeConnections) {
      try {
        await _refreshBalance(connection.info.uri);
      } catch (e) {
        logger.e(
          'Error refreshing LND balance for ${connection.info.host}: $e',
        );
        hasFailedConnection.value = true;
      }
    }
    // Update UI after all balances are refreshed
    activeConnections.refresh();
  }

  /// Get balance for a specific connection.
  Future<LndChannelBalance?> getBalance(String uri) async {
    final active = _activeConnections[uri];
    if (active == null) {
      throw Exception('LND Connection not found: $uri');
    }

    if (active.balance != null) {
      return active.balance;
    }

    return _refreshBalance(uri);
  }

  Future<LndChannelBalance> _refreshBalance(String uri) async {
    final active = _activeConnections[uri];
    if (active == null) {
      throw Exception('LND Connection not found: $uri');
    }

    final balance = await active.client.getChannelBalance();
    active.balance = balance;
    return balance;
  }

  /// Reload all connections.
  Future<void> reloadConnections() async {
    isInitialized.value = false;
    try {
      // Close existing connections
      for (final connection in _activeConnections.values) {
        connection.close();
      }
      _activeConnections.clear();
      activeConnections.clear();
      hasFailedConnection.value = false;

      // Reload from storage
      await _loadConnections();
    } catch (e) {
      logger.e('Failed to reload LND connections: $e');
      await EasyLoading.showError('Failed to reload connections');
    } finally {
      isInitialized.value = true;
    }
  }

  /// Add a new LND connection.
  Future<void> addConnection(String uri) async {
    // Check if already exists
    if (_activeConnections.containsKey(uri)) {
      throw Exception('Connection already active');
    }

    final info = LndConnectionInfo.fromUri(uri);
    await _storage.add(info);
    await _connectAndAdd(info);
    _refreshList();
  }

  /// Update connection name.
  Future<void> updateConnectionName(String uri, String newName) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('Connection not found');
      }

      final updatedInfo = LndConnectionInfo(
        uri: uri,
        host: active.info.host,
        port: active.info.port,
        macaroon: active.info.macaroon,
        tlsCert: active.info.tlsCert,
        name: newName.isEmpty ? null : newName,
        weight: active.info.weight,
      );

      await _storage.update(updatedInfo);
      active.info = updatedInfo;
      _refreshList();
      await EasyLoading.showSuccess('Connection name updated');
    } catch (e) {
      await EasyLoading.showError(e.toString());
    }
  }

  /// Delete a connection.
  Future<bool> deleteConnection(String uri) async {
    try {
      final connection = _activeConnections[uri];
      connection?.close();

      await _storage.delete(uri);
      _activeConnections.remove(uri);
      _refreshList();
      return true;
    } catch (e) {
      await EasyLoading.showError(e.toString());
      return false;
    }
  }

  /// Get node info for a connection.
  Future<LndGetInfoResponse?> getInfo(String uri) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('LND Connection not found: $uri');
      }

      if (active.nodeInfo != null) {
        return active.nodeInfo;
      }

      final info = await active.client.getInfo();
      active.nodeInfo = info;
      return info;
    } catch (e) {
      await EasyLoading.showError(e.toString());
      return null;
    }
  }

  /// List payments for a connection.
  Future<LndListPaymentsResponse?> listPayments(
    String uri, {
    int? maxPayments,
    int? indexOffset,
  }) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('LND Connection not found: $uri');
      }

      return await active.client.listPayments(
        maxPayments: maxPayments,
        indexOffset: indexOffset,
      );
    } catch (e) {
      logger.e('LND listPayments error: $e');
      return null;
    }
  }

  /// List invoices for a connection.
  Future<LndListInvoicesResponse?> listInvoices(
    String uri, {
    bool pendingOnly = false,
    int? numMaxInvoices,
    int? indexOffset,
  }) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('LND Connection not found: $uri');
      }

      return await active.client.listInvoices(
        pendingOnly: pendingOnly,
        numMaxInvoices: numMaxInvoices,
        indexOffset: indexOffset,
      );
    } catch (e) {
      logger.e('LND listInvoices error: $e');
      return null;
    }
  }

  /// Pay a Lightning invoice.
  Future<LndSendPaymentResponse?> payInvoice(
    String uri,
    String invoice, {
    int? feeLimitSat,
  }) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('LND Connection not found: $uri');
      }

      return await active.client.payInvoice(invoice, feeLimitSat: feeLimitSat);
    } catch (e) {
      logger.e('LND payInvoice error: $e');
      rethrow;
    }
  }

  /// Create a new invoice.
  Future<LndAddInvoiceResponse?> addInvoice(
    String uri,
    int amountSats, {
    String? memo,
  }) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('LND Connection not found: $uri');
      }

      return await active.client.addInvoice(amountSats, memo: memo);
    } catch (e) {
      logger.e('LND addInvoice error: $e');
      rethrow;
    }
  }

  /// Decode a payment request.
  Future<LndPayReqResponse?> decodePayReq(String uri, String payReq) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('LND Connection not found: $uri');
      }

      return await active.client.decodePayReq(payReq);
    } catch (e) {
      logger.e('LND decodePayReq error: $e');
      return null;
    }
  }

  /// Lookup an invoice by payment hash.
  Future<LndInvoice?> lookupInvoice(String uri, String rHashStr) async {
    try {
      final active = _activeConnections[uri];
      if (active == null) {
        throw Exception('LND Connection not found: $uri');
      }

      return await active.client.lookupInvoice(rHashStr);
    } catch (e) {
      logger.e('LND lookupInvoice error: $e');
      return null;
    }
  }
}
