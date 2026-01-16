import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/unified_wallet/models/cashu_wallet.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/unified_wallet/providers/wallet_provider.dart';
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
  Future<bool> addWallet(String connectionString) async {
    await _ecashController.addMintUrl(connectionString);
    return true;
  }

  @override
  Future<void> removeWallet(String walletId) async {
    // TODO: Implement mint removal in EcashController if needed
    throw UnimplementedError('Mint removal not yet implemented');
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
}
