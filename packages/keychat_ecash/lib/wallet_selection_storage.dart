import 'package:get/get.dart';
import 'package:keychat/global.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:keychat/utils.dart' show Utils;
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/nwc/nwc_controller.dart';
import 'package:keychat_ecash/unified_wallet/index.dart';
import 'package:keychat_ecash/utils.dart';

/// Storage utility for persisting and loading the user's selected wallet.
///
/// This class handles serialization and deserialization of WalletBase objects
/// (CashuWallet or NwcWallet) to/from secure storage. The wallet ID is stored
/// securely, and the corresponding wallet object is reconstructed on load by
/// looking up the wallet in the appropriate controller (EcashController for
/// Cashu wallets, NwcController for NWC wallets).
class WalletStorageSelection {
  static const String _secureKey = 'secure_ecash_wallet_selection';

  /// Load wallet selection
  static Future<WalletBase> loadWallet() async {
    return _loadWallet(_secureKey);
  }

  /// Save wallet selection
  static Future<void> saveWallet(WalletBase wallet) async {
    await _saveWallet(_secureKey, wallet);
  }

  static Future<String> getLasetMintWallet() async {
    final secureId = await SecureStorage.instance.read(_secureKey);
    final ecashController = Get.find<EcashController>();
    String getFallbackWallet() {
      final firstNonZeroBalanceMint =
          ecashController.mintBalances.firstWhereOrNull((m) => m.balance > 0);
      if (firstNonZeroBalanceMint != null) {
        return firstNonZeroBalanceMint.mint;
      }
      return KeychatGlobal.defaultCashuMintURL;
    }

    if (secureId == null) {
      return getFallbackWallet();
    }

    final isNwc = secureId.startsWith(KeychatGlobal.nwcPrefix);

    // Validate that the wallet still exists
    if (!isNwc) {
      // Cashu wallet
      final mintBalance = ecashController.mintBalances
          .firstWhereOrNull((m) => m.mint == secureId);
      if (mintBalance != null) {
        return mintBalance.mint;
      }
    }
    // nwc wallet
    return getFallbackWallet();
  }

  static Future<WalletBase> _loadWallet(String secureKey) async {
    final secureId = await SecureStorage.instance.read(secureKey);
    final ecashController = Get.find<EcashController>();

    // Default fallback wallet
    WalletBase getFallbackWallet() {
      return CashuWallet(
        mintBalance: MintBalanceClass(
          KeychatGlobal.defaultCashuMintURL,
          EcashTokenSymbol.sat.name,
          0,
        ),
      );
    }

    if (secureId == null || secureId.isEmpty) {
      final firstNonZeroBalanceMint =
          ecashController.mintBalances.firstWhereOrNull((m) => m.balance > 0);
      if (firstNonZeroBalanceMint != null) {
        return CashuWallet(mintBalance: firstNonZeroBalanceMint);
      }
      return getFallbackWallet();
    }

    // Determine type by URI format
    final isNwc = secureId.startsWith(KeychatGlobal.nwcPrefix);

    // Validate that the wallet still exists
    if (!isNwc) {
      // Cashu wallet
      final mintBalance = ecashController.mintBalances
          .firstWhereOrNull((m) => m.mint == secureId);
      if (mintBalance != null) {
        return CashuWallet(mintBalance: mintBalance);
      }
      return getFallbackWallet();
    } else {
      // NWC wallet - try to find the connection
      try {
        final nwcController = Utils.getOrPutGetxController(
          create: NwcController.new,
        );
        await nwcController.waitForLoading();
        final connection = nwcController.activeConnections.firstWhereOrNull(
          (conn) => conn.info.uri == secureId,
        );

        if (connection != null) {
          return NwcWallet(connection: connection);
        }
      } catch (e) {
        // If NWC is not available, fall back to Cashu
      }

      return getFallbackWallet();
    }
  }

  static Future<void> _saveWallet(
    String secureKey,
    WalletBase wallet,
  ) async {
    await SecureStorage.instance.write(secureKey, wallet.id);
  }
}
