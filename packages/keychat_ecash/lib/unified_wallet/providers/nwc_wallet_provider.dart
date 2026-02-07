import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat_ecash/nwc/active_nwc_connection.dart';
import 'package:keychat_ecash/nwc/nwc_controller.dart';
import 'package:keychat_ecash/nwc/nwc_models.dart';
import 'package:keychat_ecash/unified_wallet/models/nwc_wallet.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/unified_wallet/providers/wallet_provider.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

/// NWC wallet provider implementation.
class NwcWalletProvider implements WalletProvider {
  NwcWalletProvider() {
    _nwcController = Utils.getOrPutGetxController(create: NwcController.new);
  }

  late final NwcController _nwcController;
  Worker? _connectionsWorker;
  void Function(List<WalletBase> wallets)? _onWalletsChanged;

  @override
  WalletProtocol get protocol => WalletProtocol.nwc;

  @override
  bool get isLoading => !_nwcController.isInitialized.value;

  @override
  int get totalBalance => _nwcController.totalSats;

  /// Finds an active connection by its non-secret [identifier] (wallet pubkey).
  ActiveNwcConnection? _findByIdentifier(String identifier) {
    return _nwcController.activeConnections.firstWhereOrNull(
      (c) => c.identifier == identifier,
    );
  }

  @override
  Future<List<WalletBase>> getWallets() async {
    await _nwcController.waitForLoading();
    return _nwcController.activeConnections.map((connection) {
      return NwcWallet(connection: connection);
    }).toList();
  }

  @override
  Future<void> refresh() async {
    await _nwcController.reloadConnections();
  }

  @override
  Future<WalletBase?> refreshWallet(String walletId) async {
    final active = _findByIdentifier(walletId);
    if (active == null) return null;

    await _nwcController.getBalance(active.info.uri);

    return NwcWallet(connection: active);
  }

  @override
  Future<bool> addWallet(String connectionString) async {
    await _nwcController.addConnection(connectionString);
    return true;
  }

  @override
  Future<void> removeWallet(String walletId) async {
    final active = _findByIdentifier(walletId);
    if (active == null) return;
    await _nwcController.deleteConnection(active.info.uri);
  }

  @override
  Future<List<WalletTransactionBase>> getTransactions(
    String walletId, {
    int? limit,
    int? offset,
  }) async {
    final active = _findByIdentifier(walletId);
    if (active == null) return [];

    final response = await _nwcController.listTransactions(
      active.info.uri,
      limit: limit,
      offset: offset,
    );

    if (response?.transactions == null) {
      return [];
    }

    return response!.transactions
        .map((tx) => NwcWalletTransaction(transaction: tx))
        .toList();
  }

  @override
  bool canHandle(String connectionString) {
    // NWC URIs start with nostr+walletconnect://
    return connectionString.startsWith(KeychatGlobal.nwcPrefix);
  }

  @override
  Future<WalletTransactionBase?> payLightningInvoice(
    String walletId,
    String invoice,
  ) async {
    try {
      await _nwcController.waitForLoading();

      // Validate invoice
      final invoiceInfo = await rust_cashu.decodeInvoice(
        encodedInvoice: invoice,
      );

      // Find the connection by identifier
      final active = _findByIdentifier(walletId);
      if (active == null) {
        await EasyLoading.showError('NWC connection not found');
        return null;
      }

      // Check balance
      if (active.balance != null) {
        final balanceSat = (active.balance!.balanceMsats / 1000).floor();
        if (balanceSat < invoiceInfo.amount.toInt()) {
          await EasyLoading.showError('Not Enough Funds');
          return null;
        }
      }

      await EasyLoading.show(status: 'Processing...');
      final result = await _nwcController.payInvoice(
        uri: active.info.uri,
        invoice: invoice,
      );

      await EasyLoading.showSuccess('Success');

      // Refresh NWC balance
      await _nwcController.refreshNwcBalances([active]);

      return NwcWalletTransaction(
        transaction: TransactionResult(
          type: TransactionType.outgoing,
          invoice: invoice,
          amount: invoiceInfo.amount.toInt() * 1000,
          description: invoiceInfo.memo,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          feesPaid: result.feesPaid,
          preimage: result.preimage,
          paymentHash: invoiceInfo.hash,
        ),
        walletId: walletId,
      );
    } catch (e, s) {
      logger.e('NWC payment error', error: e, stackTrace: s);
      await EasyLoading.showError('Payment Failed: $e');
      return null;
    }
  }

  @override
  Future<String?> createInvoice(
    String walletId,
    int amountSats,
    String? description,
  ) async {
    try {
      await _nwcController.waitForLoading();

      final active = _findByIdentifier(walletId);
      if (active == null) {
        await EasyLoading.showError('NWC connection not found');
        return null;
      }

      await EasyLoading.show(status: 'Generating...');
      final response = await _nwcController.makeInvoice(
        uri: active.info.uri,
        amountSats: amountSats,
        description: description,
      );

      if (response == null) {
        await EasyLoading.showError('Failed to create invoice');
        return null;
      }

      await EasyLoading.showSuccess('Invoice created');
      return response.invoice;
    } catch (e, s) {
      logger.e('Failed to create NWC invoice', error: e, stackTrace: s);
      await EasyLoading.showError('Failed to create invoice: $e');
      return null;
    }
  }

  @override
  Future<NwcWalletTransaction?> createInvoiceWithTransaction(
    String walletId,
    int amountSats,
    String? description,
  ) async {
    try {
      await _nwcController.waitForLoading();

      final active = _findByIdentifier(walletId);
      if (active == null) {
        await EasyLoading.showError('NWC connection not found');
        return null;
      }

      await EasyLoading.show(status: 'Generating...');
      logger
          .d('active.info ${active.info}, active.info.uri: ${active.info.uri}');
      final response = await _nwcController.makeInvoice(
        uri: active.info.uri,
        amountSats: amountSats,
        description: description,
      );

      if (response == null) {
        await EasyLoading.showError('Failed to create invoice');
        return null;
      }

      await EasyLoading.showSuccess('Invoice created');

      return NwcWalletTransaction(
        transaction: TransactionResult(
          type: TransactionType.incoming,
          invoice: response.invoice,
          amount: response.amountMsats ?? amountSats * 1000,
          description: response.description,
          createdAt: response.createdAt ??
              DateTime.now().millisecondsSinceEpoch ~/ 1000,
          feesPaid: response.feesPaid,
          paymentHash: response.paymentHash,
          preimage: response.preimage,
        ),
        walletId: walletId,
      );
    } catch (e, s) {
      logger.e('Failed to create NWC invoice', error: e, stackTrace: s);
      await EasyLoading.showError('Failed to create invoice: $e');
      return null;
    }
  }

  @override
  void setOnWalletsChanged(void Function(List<WalletBase> wallets) callback) {
    _onWalletsChanged = callback;
    _connectionsWorker?.dispose();
    _connectionsWorker = ever(_nwcController.activeConnections, (_) {
      _notifyWalletsChanged();
    });
  }

  /// Rebuild wallet list from current active connections and notify.
  void _notifyWalletsChanged() {
    final cb = _onWalletsChanged;
    if (cb == null) return;
    try {
      final wallets = _nwcController.activeConnections.map((connection) {
        return NwcWallet(connection: connection);
      }).toList();
      cb(wallets);
    } catch (e) {
      logger.e('Failed to notify NWC wallets changed: $e');
    }
  }

  @override
  void dispose() {
    _connectionsWorker?.dispose();
    _connectionsWorker = null;
    _onWalletsChanged = null;
  }
}
