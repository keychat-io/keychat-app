import 'package:collection/collection.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:keychat/app.dart';
import 'package:keychat/global.dart';
import 'package:keychat/utils.dart' show Utils;
import 'package:keychat_ecash/unified_wallet/models/nwc_wallet.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/unified_wallet/providers/wallet_provider.dart';
import 'package:keychat_ecash/nwc/nwc_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:ndk/ndk.dart' show TransactionResult;

/// NWC wallet provider implementation
class NwcWalletProvider implements WalletProvider {
  NwcWalletProvider() {
    _nwcController = Utils.getOrPutGetxController(create: NwcController.new);
  }

  late final NwcController _nwcController;

  @override
  WalletProtocol get protocol => WalletProtocol.nwc;

  @override
  bool get isLoading => _nwcController.isInitialized.value;

  @override
  int get totalBalance => _nwcController.totalSats;

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
    // For NWC, refresh the specific connection's balance
    await _nwcController.getBalance(walletId);

    // Return the updated wallet
    final connections = _nwcController.activeConnections.toList();
    final connection = connections.firstWhereOrNull(
      (c) => c.info.uri == walletId,
    );
    if (connection == null) return null;

    return NwcWallet(connection: connection);
  }

  @override
  Future<bool> addWallet(String connectionString) async {
    await _nwcController.addConnection(connectionString);
    return true;
  }

  @override
  Future<void> removeWallet(String walletId) async {
    await _nwcController.deleteConnection(walletId);
  }

  @override
  Future<List<WalletTransactionBase>> getTransactions(
    String walletId, {
    int? limit,
    int? offset,
  }) async {
    final response = await _nwcController.listTransactions(
      walletId,
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

      // Find the connection
      final active = _nwcController.activeConnections.firstWhereOrNull(
        (c) => c.info.uri == walletId,
      );
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

      EasyLoading.show(status: 'Processing...');
      final result = await _nwcController.ndk.nwc.payInvoice(
        active.connection,
        invoice: invoice,
      );
      await EasyLoading.showSuccess('Success');

      // Refresh NWC balance
      await _nwcController.refreshNwcBalances([active]);

      return NwcWalletTransaction(
        transaction: TransactionResult(
          type: 'outgoing',
          invoice: invoice,
          amount: invoiceInfo.amount.toInt() * 1000,
          description: invoiceInfo.memo,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          feesPaid: result.feesPaid ~/ 1000,
          preimage: result.preimage,
          paymentHash: 'none',
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

      final active = _nwcController.activeConnections.firstWhereOrNull(
        (c) => c.info.uri == walletId,
      );
      if (active == null) {
        await EasyLoading.showError('NWC connection not found');
        return null;
      }

      EasyLoading.show(status: 'Generating...');
      final response = await _nwcController.ndk.nwc.makeInvoice(
        active.connection,
        amountSats: amountSats,
        description: description ?? '',
      );
      await EasyLoading.showSuccess('Invoice created');
      return response.invoice;
    } catch (e, s) {
      logger.e('Failed to create NWC invoice', error: e, stackTrace: s);
      await EasyLoading.showError('Failed to create invoice: $e');
      return null;
    }
  }

  /// Create invoice and return the full transaction
  Future<NwcWalletTransaction?> createInvoiceWithTransaction(
    String walletId,
    int amountSats,
    String? description,
  ) async {
    try {
      await _nwcController.waitForLoading();

      final active = _nwcController.activeConnections.firstWhereOrNull(
        (c) => c.info.uri == walletId,
      );
      if (active == null) {
        await EasyLoading.showError('NWC connection not found');
        return null;
      }

      EasyLoading.show(status: 'Generating...');
      final response = await _nwcController.ndk.nwc.makeInvoice(
        active.connection,
        amountSats: amountSats,
        description: description ?? '',
      );
      await EasyLoading.showSuccess('Invoice created');

      return NwcWalletTransaction(
        transaction: TransactionResult(
          type: 'incoming',
          invoice: response.invoice,
          amount: response.amountSat * 1000,
          description: response.description,
          createdAt: response.createdAt,
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
}
