import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/unified_wallet/models/cashu_wallet.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/unified_wallet/providers/wallet_provider.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

/// Cashu wallet provider implementation
class CashuWalletProvider implements WalletProvider {
  CashuWalletProvider() {
    _ecashController = Get.find<EcashController>();
  }

  late final EcashController _ecashController;

  @override
  WalletProtocol get protocol => WalletProtocol.cashu;

  @override
  bool get isLoading => _ecashController.isBalanceLoading.value;

  @override
  int get totalBalance => _ecashController.totalSats.value;

  @override
  Future<List<WalletBase>> getWallets() async {
    // Wait for Cashu to be initialized
    await _ecashController.waitForInit();
    return _ecashController.mintBalances.map((mintBalance) {
      return CashuWallet(
        mintBalance: mintBalance,
        supportsMint: _ecashController.supportMint(mintBalance.mint),
        supportsMelt: _ecashController.supportMelt(mintBalance.mint),
      );
    }).toList();
  }

  @override
  Future<void> refresh() async {
    await _ecashController.requestPageRefresh();
  }

  @override
  Future<WalletBase?> refreshWallet(String walletId) async {
    // For Cashu, refresh the specific mint balance
    await _ecashController.getBalance();
    _ecashController.getBalanceByMint(walletId);

    // Return the updated wallet
    final mintBalance = _ecashController.mintBalances.firstWhereOrNull(
      (mb) => mb.mint == walletId,
    );
    if (mintBalance == null) return null;

    return CashuWallet(
      mintBalance: mintBalance,
      supportsMint: _ecashController.supportMint(mintBalance.mint),
      supportsMelt: _ecashController.supportMelt(mintBalance.mint),
    );
  }

  @override
  Future<bool> addWallet(String connectionString) async {
    await _ecashController.addMintUrl(connectionString);
    return true;
  }

  @override
  Future<void> removeWallet(String walletId) async {
    await rust_cashu.removeMint(url: walletId);
  }

  @override
  Future<List<WalletTransactionBase>> getTransactions(
    String walletId, {
    int? limit,
    int? offset,
  }) async {
    final transactions = await rust_cashu.getTransactionsWithOffset(
      limit: BigInt.from(limit ?? 20),
      offset: BigInt.from(offset ?? 0),
    );

    // Filter by mint if specified
    return transactions
        .where((tx) => tx.mintUrl == walletId || walletId.isEmpty)
        .map((tx) => CashuWalletTransaction(transaction: tx))
        .toList();
  }

  @override
  bool canHandle(String connectionString) {
    // Cashu mints are HTTP(S) URLs
    return connectionString.startsWith('http://') ||
        connectionString.startsWith('https://');
  }

  @override
  Future<WalletTransactionBase?> payLightningInvoice(
    String walletId,
    String invoice,
  ) async {
    try {
      // Validate invoice
      final invoiceInfo = await rust_cashu.decodeInvoice(
        encodedInvoice: invoice,
      );

      // Check balance
      if (_ecashController.getBalanceByMint(walletId) <
          invoiceInfo.amount.toInt()) {
        await EasyLoading.showToast('Not Enough Funds');
        return null;
      }

      EasyLoading.show(status: 'Processing...');
      final tx = await rust_cashu.melt(invoice: invoice, activeMint: walletId);
      logger.i('CashuWalletProvider: payLightningInvoice success: $tx');
      await EasyLoading.showSuccess('Success');

      return CashuWalletTransaction(transaction: tx, walletId: walletId);
    } catch (e, s) {
      final msg = await EcashUtils.ecashErrorHandle(e, s);
      await EasyLoading.showError(msg);
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
      EasyLoading.show(status: 'Generating...');
      final tx = await rust_cashu.requestMint(
        amount: BigInt.from(amountSats),
        activeMint: walletId,
      );
      await EasyLoading.showSuccess('Invoice created');
      return tx.token;
    } catch (e, s) {
      logger.e('Failed to create invoice', error: e, stackTrace: s);
      await EasyLoading.showError('Failed to create invoice: $e');
      return null;
    }
  }

  /// Create invoice and return the full transaction
  Future<CashuWalletTransaction?> createInvoiceWithTransaction(
    String walletId,
    int amountSats,
    String? description,
  ) async {
    try {
      EasyLoading.show(status: 'Generating...');
      final tx = await rust_cashu.requestMint(
        amount: BigInt.from(amountSats),
        activeMint: walletId,
      );
      await EasyLoading.showSuccess('Invoice created');
      return CashuWalletTransaction(transaction: tx, walletId: walletId);
    } catch (e, s) {
      logger.e('Failed to create invoice', error: e, stackTrace: s);
      await EasyLoading.showError('Failed to create invoice: $e');
      return null;
    }
  }
}
