import 'package:keychat/utils.dart' show Utils;
import 'package:keychat_ecash/unified_wallet/models/nwc_wallet.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/unified_wallet/providers/wallet_provider.dart';
import 'package:keychat_nwc/nwc/nwc_controller.dart';
import 'package:keychat_nwc/utils.dart';

/// NWC wallet provider implementation
class NwcWalletProvider implements WalletProvider {
  NwcWalletProvider() {
    _nwcController = Utils.getOrPutGetxController(create: NwcController.new);
  }

  late final NwcController _nwcController;

  @override
  WalletProtocol get protocol => WalletProtocol.nwc;

  @override
  bool get isLoading => _nwcController.isLoading.value;

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
    return connectionString.startsWith(NwcUtils.nwcPrefix);
  }
}
