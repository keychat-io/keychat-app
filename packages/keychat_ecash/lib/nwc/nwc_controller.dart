import 'package:keychat/app.dart';
import 'package:keychat_ecash/nwc/index.dart';
import 'package:keychat_ecash/unified_wallet/base_connection_controller.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart'
    show WalletProtocol;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart'
    show TransactionStatus;

/// Controller for managing NWC (Nostr Wallet Connect) connections.
class NwcController
    extends BaseConnectionController<ActiveNwcConnection, NwcConnectionInfo> {
  @override
  WalletProtocol get protocol => WalletProtocol.nwc;

  // ---------------------------------------------------------------------------
  // BaseConnectionController hooks
  // ---------------------------------------------------------------------------

  @override
  int balanceFromConnection(ActiveNwcConnection connection) =>
      connection.balance?.balanceSats ?? 0;

  @override
  NwcConnectionInfo parseUri(String uri, {String? name}) =>
      NwcConnectionInfo(uri: uri, name: name);

  @override
  String identifierFromInfo(NwcConnectionInfo info) {
    final params = NwcUriParser.parse(info.uri);
    return params.walletPubkey;
  }

  @override
  String uriFromInfo(NwcConnectionInfo info) => info.uri;

  @override
  Future<ActiveNwcConnection?> connect(
    NwcConnectionInfo info, {
    required String identifier,
    int? walletConnectionId,
  }) async {
    final client = await NwcClient.fromUri(info.uri);
    client.subscribe();

    return ActiveNwcConnection(
      info: info,
      client: client,
      identifier: identifier,
      walletConnectionId: walletConnectionId,
    );
  }

  @override
  void closeConnection(ActiveNwcConnection connection) =>
      connection.client.close();

  @override
  Future<void> refreshBalance(ActiveNwcConnection connection) async {
    connection.balance = await connection.client.getBalance();
  }

  @override
  NwcConnectionInfo updateInfoName(
    ActiveNwcConnection connection,
    String? newName,
  ) {
    return NwcConnectionInfo(
      uri: connection.info.uri,
      name: newName,
      weight: connection.info.weight,
    );
  }

  @override
  void setConnectionInfo(
    ActiveNwcConnection connection,
    NwcConnectionInfo info,
  ) {
    connection.info = info;
  }

  @override
  int? getStorageId(ActiveNwcConnection connection) =>
      connection.walletConnectionId;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> onInit() async {
    super.onInit();
    await loadConnections();
  }

  @override
  void onClose() {
    NwcRequestManager.instance.cancelAll();
    for (final connection in connectionMap.values) {
      closeConnection(connection);
    }
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // NWC-specific balance helpers (kept for direct callers like provider)
  // ---------------------------------------------------------------------------

  /// Refresh balances for the given [connections], or all if null.
  Future<void> refreshNwcBalances([
    List<ActiveNwcConnection>? connections,
  ]) =>
      refreshAllBalances(connections);

  /// Get cached balance, or refresh if not yet loaded.
  Future<GetBalanceResponse?> getBalance(String nwcUri) async {
    final active = getConnectionByUri(nwcUri);
    if (active.balance != null) return active.balance;
    await refreshBalance(active);
    return active.balance;
  }

  // ---------------------------------------------------------------------------
  // NWC protocol operations
  // ---------------------------------------------------------------------------

  /// Processes an NWC response event from a relay.
  ///
  /// Routes the response to the appropriate client by matching wallet pubkey.
  Future<void> processResponseEvent(Map<String, dynamic> eventData) async {
    final walletPubkey = eventData['pubkey'] as String?;
    if (walletPubkey == null) return;

    for (final connection in connectionMap.values) {
      if (connection.client.walletPubkey == walletPubkey) {
        await connection.client.processResponseEvent(eventData);
        return;
      }
    }

    logger.d('No NWC client found for wallet pubkey: $walletPubkey');
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
      await listTransactions(uri, limit: 10);
      refreshList();
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
      final active = getConnectionByUri(uri);
      final response = await active.client.listTransactions(
        from: from,
        until: until,
        limit: limit,
        offset: offset,
        unpaid: unpaid,
      );
      active.transactions = response;
      return response;
    } catch (e, stackTrace) {
      logger.e('nwc listTransactions: $e', stackTrace: stackTrace);
      return null;
    }
  }

  Future<GetInfoResponse?> getInfo(String uri) async {
    try {
      final active = getConnectionByUri(uri);
      return await active.client.getInfo();
    } catch (e) {
      logger.e('NWC getInfo error: $e');
      return null;
    }
  }

  Future<LookupInvoiceResponse?> lookupInvoice({
    required String uri,
    String? invoice,
    String? paymentHash,
  }) async {
    try {
      final active = getConnectionByUri(uri);
      await waitForLoading();
      return await active.client.lookupInvoice(
        invoice: invoice,
        paymentHash: paymentHash,
      );
    } catch (e) {
      logger.e('NWC lookupInvoice error: $e');
      return null;
    }
  }

  /// Pays a lightning invoice. Throws on error.
  Future<PayInvoiceResponse> payInvoice({
    required String uri,
    required String invoice,
  }) async {
    final active = getConnectionByUri(uri);
    await waitForLoading();
    return active.client.payInvoice(invoice);
  }

  /// Creates a new invoice.
  Future<MakeInvoiceResponse?> makeInvoice({
    required String uri,
    required int amountSats,
    String? description,
  }) async {
    try {
      final active = getConnectionByUri(uri);
      await waitForLoading();
      final res = await active.client.makeInvoice(
        amountSats: amountSats,
        description: description,
      );
      logger.d('NWC makeInvoice success: $res');
      return res;
    } catch (e) {
      logger.e('NWC makeInvoice error', error: e);
      return null;
    }
  }

  /// Gets the active client for a given URI.
  NwcClient? getClient(String uri) {
    return connectionMap[uri]?.client;
  }

  TransactionStatus getTransactionStatus(TransactionResult transaction) {
    if (transaction.isSettled) return TransactionStatus.success;
    if (transaction.isExpired) return TransactionStatus.expired;
    return TransactionStatus.pending;
  }
}
