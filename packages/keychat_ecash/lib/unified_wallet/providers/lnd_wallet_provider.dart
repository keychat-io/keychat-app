import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/utils.dart' show Utils;
import 'package:keychat_ecash/lnd/active_lnd_connection.dart';
import 'package:keychat_ecash/lnd/lnd_connection_info.dart';
import 'package:keychat_ecash/lnd/lnd_controller.dart';
import 'package:keychat_ecash/lnd/lnd_rest_client.dart';
import 'package:keychat_ecash/unified_wallet/models/lnd_wallet.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/unified_wallet/providers/wallet_provider.dart';

/// LND wallet provider implementation for the unified wallet system.
class LndWalletProvider implements WalletProvider {
  LndWalletProvider() {
    _lndController = Utils.getOrPutGetxController(create: LndController.new);
  }

  late final LndController _lndController;
  Worker? _connectionsWorker;
  void Function(List<WalletBase> wallets)? _onWalletsChanged;

  @override
  WalletProtocol get protocol => WalletProtocol.lnd;

  @override
  bool get isLoading => !_lndController.isInitialized.value;

  @override
  int get totalBalance => _lndController.totalSats;

  /// Finds an active connection by its non-secret [identifier] (host:port).
  ActiveLndConnection? _findByIdentifier(String identifier) {
    return _lndController.activeConnections.firstWhereOrNull(
      (c) => c.identifier == identifier,
    );
  }

  @override
  Future<List<WalletBase>> getWallets() async {
    await _lndController.waitForLoading();
    return _lndController.activeConnections.map((connection) {
      return LndWallet(connection: connection);
    }).toList();
  }

  @override
  Future<void> refresh() async {
    await _lndController.reloadConnections();
  }

  @override
  Future<WalletBase?> refreshWallet(String walletId) async {
    final active = _findByIdentifier(walletId);
    if (active == null) return null;

    await _lndController.getBalance(active.info.uri);

    return LndWallet(connection: active);
  }

  @override
  Future<bool> addWallet(String connectionString) async {
    await _lndController.addConnection(connectionString);
    return true;
  }

  @override
  Future<void> removeWallet(String walletId) async {
    final active = _findByIdentifier(walletId);
    if (active == null) return;
    await _lndController.deleteConnection(active.info.uri);
  }

  @override
  Future<List<WalletTransactionBase>> getTransactions(
    String walletId, {
    int? limit,
    int? offset,
  }) async {
    final active = _findByIdentifier(walletId);
    if (active == null) return [];

    final uri = active.info.uri;
    final transactions = <WalletTransactionBase>[];

    // Get payments (outgoing)
    final paymentsResponse = await _lndController.listPayments(
      uri,
      maxPayments: limit,
      indexOffset: offset,
    );

    if (paymentsResponse?.payments != null) {
      for (final payment in paymentsResponse!.payments) {
        transactions.add(
          LndWalletTransaction.fromPayment(
            payment: payment,
            walletId: walletId,
          ),
        );
      }
    }

    // Get invoices (incoming)
    final invoicesResponse = await _lndController.listInvoices(
      uri,
      numMaxInvoices: limit,
      indexOffset: offset,
    );

    if (invoicesResponse?.invoices != null) {
      for (final invoice in invoicesResponse!.invoices) {
        transactions.add(
          LndWalletTransaction.fromInvoice(
            invoice: invoice,
            walletId: walletId,
          ),
        );
      }
    }

    // Sort by timestamp descending
    transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Apply limit if both payments and invoices were fetched
    if (limit != null && transactions.length > limit) {
      return transactions.take(limit).toList();
    }

    return transactions;
  }

  @override
  bool canHandle(String connectionString) {
    // LND URIs start with lndconnect://
    return connectionString.startsWith(LndConnectionInfo.lndConnectPrefix);
  }

  @override
  Future<WalletTransactionBase?> payLightningInvoice(
    String walletId,
    String invoice,
  ) async {
    try {
      await _lndController.waitForLoading();

      // Find the connection by identifier
      final active = _findByIdentifier(walletId);
      if (active == null) {
        await EasyLoading.showError('LND connection not found');
        return null;
      }

      final uri = active.info.uri;

      // Decode invoice to check amount
      final decoded = await _lndController.decodePayReq(uri, invoice);
      if (decoded == null) {
        await EasyLoading.showError('Failed to decode invoice');
        return null;
      }

      // Check balance
      if (active.balance != null) {
        final balanceSat = active.balance!.spendableBalanceSat;
        if (balanceSat < decoded.numSatoshis) {
          await EasyLoading.showError('Not Enough Funds');
          return null;
        }
      }

      EasyLoading.show(status: 'Processing...');
      final result = await _lndController.payInvoice(uri, invoice);

      if (result == null || !result.isSuccess) {
        await EasyLoading.showError(
          result?.paymentError ?? 'Payment failed',
        );
        return null;
      }

      await EasyLoading.showSuccess('Success');

      // Refresh balance
      await _lndController.refreshAllBalances([active]);

      // Return transaction
      return LndWalletTransaction.fromPayment(
        payment: _createPaymentFromResult(result, decoded, invoice),
        walletId: walletId,
      );
    } catch (e, s) {
      logger.e('LND payment error', error: e, stackTrace: s);
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
      await _lndController.waitForLoading();

      final active = _findByIdentifier(walletId);
      if (active == null) {
        await EasyLoading.showError('LND connection not found');
        return null;
      }

      EasyLoading.show(status: 'Generating...');
      final response = await _lndController.addInvoice(
        active.info.uri,
        amountSats,
        memo: description,
      );

      if (response == null) {
        await EasyLoading.showError('Failed to create invoice');
        return null;
      }

      await EasyLoading.showSuccess('Invoice created');
      return response.paymentRequest;
    } catch (e, s) {
      logger.e('Failed to create LND invoice', error: e, stackTrace: s);
      await EasyLoading.showError('Failed to create invoice: $e');
      return null;
    }
  }

  @override
  Future<LndWalletTransaction?> createInvoiceWithTransaction(
    String walletId,
    int amountSats,
    String? description,
  ) async {
    try {
      await _lndController.waitForLoading();

      final active = _findByIdentifier(walletId);
      if (active == null) {
        await EasyLoading.showError('LND connection not found');
        return null;
      }

      final uri = active.info.uri;

      EasyLoading.show(status: 'Generating...');
      final response = await _lndController.addInvoice(
        uri,
        amountSats,
        memo: description,
      );

      if (response == null) {
        await EasyLoading.showError('Failed to create invoice');
        return null;
      }

      await EasyLoading.showSuccess('Invoice created');

      // Lookup the created invoice to get full details
      final invoice = await _lndController.lookupInvoice(
        uri,
        response.rHash,
      );

      if (invoice != null) {
        return LndWalletTransaction.fromInvoice(
          invoice: invoice,
          walletId: walletId,
        );
      }

      // Fallback: create a minimal invoice object
      return LndWalletTransaction.fromInvoice(
        invoice: _createInvoiceFromResponse(response, amountSats, description),
        walletId: walletId,
      );
    } catch (e, s) {
      logger.e('Failed to create LND invoice', error: e, stackTrace: s);
      await EasyLoading.showError('Failed to create invoice: $e');
      return null;
    }
  }

  /// Create a Payment object from the payment result.
  LndPayment _createPaymentFromResult(
    LndSendPaymentResponse result,
    LndPayReqResponse decoded,
    String invoice,
  ) {
    return LndPayment(
      paymentHash: result.paymentHash,
      valueSat: decoded.numSatoshis,
      creationDate: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      status: result.isSuccess
          ? LndPaymentStatus.succeeded
          : LndPaymentStatus.failed,
      feeSat: result.paymentRoute?.totalFeesSat,
      paymentPreimage: result.paymentPreimage,
      paymentRequest: invoice,
    );
  }

  /// Create an Invoice object from the add invoice response.
  LndInvoice _createInvoiceFromResponse(
    LndAddInvoiceResponse response,
    int amountSats,
    String? memo,
  ) {
    return LndInvoice(
      rHash: response.rHash,
      paymentRequest: response.paymentRequest,
      valueSat: amountSats,
      creationDate: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      expiry: 3600,
      settled: false,
      memo: memo,
    );
  }

  @override
  void setOnWalletsChanged(void Function(List<WalletBase> wallets) callback) {
    _onWalletsChanged = callback;
    _connectionsWorker?.dispose();
    _connectionsWorker = ever(_lndController.activeConnections, (_) {
      _notifyWalletsChanged();
    });
  }

  /// Rebuild wallet list from current active connections and notify.
  void _notifyWalletsChanged() {
    final cb = _onWalletsChanged;
    if (cb == null) return;
    try {
      final wallets = _lndController.activeConnections.map((connection) {
        return LndWallet(connection: connection);
      }).toList();
      cb(wallets);
    } catch (e) {
      logger.e('Failed to notify LND wallets changed: $e');
    }
  }

  @override
  void dispose() {
    _connectionsWorker?.dispose();
    _connectionsWorker = null;
    _onWalletsChanged = null;
  }
}
