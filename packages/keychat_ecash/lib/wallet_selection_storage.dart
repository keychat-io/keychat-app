import 'package:get/get.dart';
import 'package:keychat/global.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/unified_wallet/index.dart';
import 'package:keychat_ecash/utils.dart';

/// Storage utility for persisting and loading the user's selected wallet.
///
/// Stores the non-secret wallet identifier (mint URL for Cashu, wallet pubkey
/// for NWC, host:port for LND) to secure storage. On load, looks up the wallet
/// in [UnifiedWalletController.wallets] by matching [WalletBase.id].
///
/// Fallback priority when the saved wallet is not found (e.g. deleted):
/// 1. The wallet with the highest balance
/// 2. A default Cashu wallet
class WalletStorageSelection {
  static const String _secureKey = 'secure_ecash_wallet_selection';

  /// Load the previously selected wallet.
  ///
  /// Returns the saved wallet if it still exists, otherwise falls back to
  /// the highest-balance wallet, then the default Cashu mint.
  static Future<WalletBase> loadWallet() async {
    final savedId = await SecureStorage.instance.read(_secureKey);

    // Try to find the saved wallet in the unified controller
    if (savedId != null && savedId.isNotEmpty) {
      final wallet = _findWalletById(savedId);
      if (wallet != null) return wallet;
    }

    // Fallback: highest balance wallet
    final highestBalance = _findHighestBalanceWallet();
    if (highestBalance != null) return highestBalance;

    // Fallback: default Cashu wallet
    return _defaultCashuWallet();
  }

  /// Save the selected wallet identifier to secure storage.
  static Future<void> saveWallet(WalletBase wallet) async {
    await SecureStorage.instance.write(_secureKey, wallet.id);
  }

  /// Returns the last selected Cashu mint URL (for ecash-specific operations).
  ///
  /// Falls back to the first non-zero balance Cashu mint, then the default.
  static Future<String> getLastMintWallet() async {
    final savedId = await SecureStorage.instance.read(_secureKey);

    if (savedId != null && savedId.isNotEmpty) {
      // If the saved ID is a Cashu mint URL, validate it still exists
      final ecashController = Get.find<EcashController>();
      final mintBalance = ecashController.mintBalances
          .firstWhereOrNull((m) => m.mint == savedId);
      if (mintBalance != null) return mintBalance.mint;
    }

    // Fallback: first Cashu mint with balance
    return _fallbackMintUrl();
  }

  /// Finds a wallet by its [id] in the unified controller.
  static WalletBase? _findWalletById(String id) {
    try {
      final controller = Get.find<UnifiedWalletController>();
      return controller.wallets.firstWhereOrNull((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns the wallet with the highest balance across all protocols.
  static WalletBase? _findHighestBalanceWallet() {
    try {
      final controller = Get.find<UnifiedWalletController>();
      if (controller.wallets.isEmpty) return null;

      WalletBase? best;
      for (final w in controller.wallets) {
        if (best == null || w.balanceSats > best.balanceSats) {
          best = w;
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  /// Returns the default Cashu wallet as last resort fallback.
  static WalletBase _defaultCashuWallet() {
    try {
      final ecashController = Get.find<EcashController>();
      final firstWithBalance =
          ecashController.mintBalances.firstWhereOrNull((m) => m.balance > 0);
      if (firstWithBalance != null) {
        return CashuWallet(mintBalance: firstWithBalance);
      }
    } catch (_) {
      // EcashController not available
    }

    return CashuWallet(
      mintBalance: MintBalanceClass(
        KeychatGlobal.defaultCashuMintURL,
        EcashTokenSymbol.sat.name,
        0,
      ),
    );
  }

  /// Returns a Cashu mint URL fallback.
  static String _fallbackMintUrl() {
    try {
      final ecashController = Get.find<EcashController>();
      final firstWithBalance =
          ecashController.mintBalances.firstWhereOrNull((m) => m.balance > 0);
      if (firstWithBalance != null) return firstWithBalance.mint;
    } catch (_) {
      // EcashController not available
    }
    return KeychatGlobal.defaultCashuMintURL;
  }
}
