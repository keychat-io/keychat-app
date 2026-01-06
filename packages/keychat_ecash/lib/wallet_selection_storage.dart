import 'package:keychat/service/storage.dart';
import 'package:keychat_ecash/components/SelectMintAndNwc.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_nwc/nwc/nwc_controller.dart';
import 'package:get/get.dart';
import 'package:keychat/utils.dart' show Utils;

class WalletSelectionStorage {
  static const String _key = 'wallet_selection';

  /// Load wallet selection
  static WalletSelection loadWallet() {
    return _loadWallet(_key);
  }

  /// Save wallet selection
  static Future<void> saveWallet(WalletSelection wallet) async {
    await _saveWallet(_key, wallet);
  }

  static WalletSelection _loadWallet(String key) {
    try {
      final id = Storage.sp.getString(key);
      if (id != null && id.isNotEmpty) {
        // Determine type by URI format
        final isNwc = id.startsWith('nostr+walletconnect://');
        final type = isNwc ? WalletType.nwc : WalletType.cashu;

        // Validate that the wallet still exists and get displayName
        if (type == WalletType.cashu) {
          final ecashController = Get.find<EcashController>();
          final exists = ecashController.mintBalances.any((m) => m.mint == id);
          if (exists) {
            return WalletSelection(
              type: type,
              id: id,
              displayName: id,
            );
          }
        } else {
          final nwcController = Utils.getOrPutGetxController(
            create: NwcController.new,
          );
          final connection = nwcController.activeConnections.firstWhereOrNull(
            (c) => c.info.uri == id,
          );
          if (connection != null) {
            final displayName = connection.info.name ?? id;
            return WalletSelection(
              type: type,
              id: id,
              displayName: displayName,
            );
          }
        }
      }
    } catch (e) {
      // Ignore errors and fall back to default
    }

    // Fallback to default cashu mint
    final ecashController = Get.find<EcashController>();
    final latestMintUrl = ecashController.latestMintUrl.value;
    return WalletSelection(
      type: WalletType.cashu,
      id: latestMintUrl,
      displayName: latestMintUrl,
    );
  }

  static Future<void> _saveWallet(
    String key,
    WalletSelection wallet,
  ) async {
    await Storage.sp.setString(key, wallet.id);
  }
}
