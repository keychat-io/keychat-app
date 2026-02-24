import 'dart:async';

import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat_ecash/lnd/active_lnd_connection.dart';
import 'package:keychat_ecash/lnd/lnd_connection_info.dart';
import 'package:keychat_ecash/lnd/lnd_rest_client.dart';
import 'package:keychat_ecash/unified_wallet/base_connection_controller.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart'
    show WalletProtocol;

/// GetX controller for managing LND wallet connections.
class LndController
    extends BaseConnectionController<ActiveLndConnection, LndConnectionInfo> {
  /// Flag to indicate if any LND connection has failed.
  final RxBool hasFailedConnection = false.obs;

  @override
  WalletProtocol get protocol => WalletProtocol.lnd;

  // ---------------------------------------------------------------------------
  // BaseConnectionController hooks
  // ---------------------------------------------------------------------------

  @override
  int balanceFromConnection(ActiveLndConnection connection) =>
      connection.balance?.spendableBalanceSat ?? 0;

  @override
  LndConnectionInfo parseUri(String uri, {String? name}) =>
      LndConnectionInfo.fromUri(uri, name: name);

  @override
  String identifierFromInfo(LndConnectionInfo info) =>
      '${info.host}:${info.port}';

  @override
  String uriFromInfo(LndConnectionInfo info) => info.uri;

  @override
  Future<ActiveLndConnection?> connect(
    LndConnectionInfo info, {
    required String identifier,
    int? walletConnectionId,
  }) async {
    try {
      final client = LndRestClient(info);
      final nodeInfo = await client.getInfo();

      return ActiveLndConnection(
        info: info,
        client: client,
        identifier: identifier,
        walletConnectionId: walletConnectionId,
        nodeInfo: nodeInfo,
      );
    } catch (e) {
      logger.e(
        'Failed to connect to LND: ${info.host}:${info.port} error: $e',
      );
      hasFailedConnection.value = true;
      return null;
    }
  }

  @override
  void closeConnection(ActiveLndConnection connection) => connection.close();

  @override
  Future<void> refreshBalance(ActiveLndConnection connection) async {
    try {
      connection.balance = await connection.client.getChannelBalance();
    } catch (e) {
      hasFailedConnection.value = true;
      rethrow;
    }
  }

  @override
  LndConnectionInfo updateInfoName(
    ActiveLndConnection connection,
    String? newName,
  ) {
    return LndConnectionInfo(
      uri: connection.info.uri,
      host: connection.info.host,
      port: connection.info.port,
      macaroon: connection.info.macaroon,
      tlsCert: connection.info.tlsCert,
      name: newName,
      weight: connection.info.weight,
    );
  }

  @override
  void setConnectionInfo(ActiveLndConnection connection, LndConnectionInfo info) {
    connection.info = info;
  }

  @override
  int? getStorageId(ActiveLndConnection connection) =>
      connection.walletConnectionId;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void onInit() {
    super.onInit();
    unawaited(loadConnections());
  }

  @override
  void onClose() {
    for (final connection in connectionMap.values) {
      closeConnection(connection);
    }
    super.onClose();
  }

  @override
  Future<void> reloadConnections() async {
    hasFailedConnection.value = false;
    await super.reloadConnections();
  }

  // ---------------------------------------------------------------------------
  // LND-specific balance helpers
  // ---------------------------------------------------------------------------

  /// Get cached balance, or refresh if not yet loaded.
  Future<LndChannelBalance?> getBalance(String uri) async {
    final active = getConnectionByUri(uri);
    if (active.balance != null) return active.balance;
    await refreshBalance(active);
    return active.balance;
  }

  // ---------------------------------------------------------------------------
  // LND protocol operations
  // ---------------------------------------------------------------------------

  /// Get node info for a connection.
  Future<LndGetInfoResponse?> getInfo(String uri) async {
    try {
      final active = getConnectionByUri(uri);
      if (active.nodeInfo != null) return active.nodeInfo;

      final info = await active.client.getInfo();
      active.nodeInfo = info;
      return info;
    } catch (e) {
      logger.e('LND getInfo error: $e');
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
      final active = getConnectionByUri(uri);
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
      final active = getConnectionByUri(uri);
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
      final active = getConnectionByUri(uri);
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
      final active = getConnectionByUri(uri);
      return await active.client.addInvoice(amountSats, memo: memo);
    } catch (e) {
      logger.e('LND addInvoice error: $e');
      rethrow;
    }
  }

  /// Decode a payment request.
  Future<LndPayReqResponse?> decodePayReq(String uri, String payReq) async {
    try {
      final active = getConnectionByUri(uri);
      return await active.client.decodePayReq(payReq);
    } catch (e) {
      logger.e('LND decodePayReq error: $e');
      return null;
    }
  }

  /// Lookup an invoice by payment hash.
  Future<LndInvoice?> lookupInvoice(String uri, String rHashStr) async {
    try {
      final active = getConnectionByUri(uri);
      return await active.client.lookupInvoice(rHashStr);
    } catch (e) {
      logger.e('LND lookupInvoice error: $e');
      return null;
    }
  }
}
