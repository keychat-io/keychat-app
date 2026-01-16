import 'package:keychat/service/secure_storage.dart';
import 'package:keychat_ecash/components/SelectMintAndNwc.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_nwc/nwc_connection_storage.dart';
import 'package:keychat_nwc/utils.dart';
import 'package:get/get.dart';

class WalletSelectionStorage {
  static const String _secureKey = 'secure_ecash_wallet_selection';

  /// Load wallet selection
  static Future<WalletSelection> loadWallet() async {
    return _loadWallet(_secureKey);
  }

  /// Save wallet selection
  static Future<void> saveWallet(WalletSelection wallet) async {
    await _saveWallet(_secureKey, wallet);
  }

  static Future<WalletSelection> _loadWallet(String secureKey) async {
    final secureId = await SecureStorage.instance.read(secureKey);
    final ecashController = Get.find<EcashController>();

    final latestMintUrl = ecashController.latestMintUrl.value;
    final fall = WalletSelection(
      type: WalletType.cashu,
      id: latestMintUrl,
      displayName: latestMintUrl,
    );

    if (secureId == null || secureId.isEmpty) {
      final firstNonZeroBalanceMint =
          ecashController.mintBalances.firstWhereOrNull((m) => m.balance > 0);
      if (firstNonZeroBalanceMint != null) {
        return WalletSelection(
          type: WalletType.cashu,
          id: firstNonZeroBalanceMint.mint,
          displayName: firstNonZeroBalanceMint.mint,
        );
      }
      return fall;
    }

    // Determine type by URI format
    final isNwc = secureId.startsWith(NwcUtils.nwcPrefix);
    final type = isNwc ? WalletType.nwc : WalletType.cashu;

    // Validate that the wallet still exists
    if (type == WalletType.cashu) {
      final exists =
          ecashController.mintBalances.any((m) => m.mint == secureId);
      if (exists) {
        return WalletSelection(
          type: type,
          id: secureId,
          displayName: secureId,
        );
      }
      return fall;
    } else if (type == WalletType.nwc) {
      // Check if NWC connection still exists
      final storage = NwcConnectionStorage();
      final savedConnections = await storage.getAll();
      final exists = savedConnections.any((conn) => conn.uri == secureId);

      if (exists) {
        return WalletSelection(
          type: type,
          id: secureId,
          displayName: secureId,
        );
      }
      return fall;
    }
    return fall;
  }

  static Future<void> _saveWallet(
    String secureKey,
    WalletSelection wallet,
  ) async {
    await SecureStorage.instance.write(secureKey, wallet.id);
  }
}
