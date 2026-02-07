import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';

/// Abstract interface for wallet data providers.
///
/// Each wallet protocol (Cashu, NWC, LND) implements this interface to
/// provide a unified API for wallet operations. Providers also support
/// reactive balance updates via [setOnWalletsChanged].
abstract class WalletProvider {
  /// The protocol type this provider handles.
  WalletProtocol get protocol;

  /// Get all wallets managed by this provider.
  Future<List<WalletBase>> getWallets();

  /// Refresh wallet data (balances, etc.).
  Future<void> refresh();

  /// Refresh a specific wallet's data (balance, transactions).
  /// Returns the updated wallet.
  Future<WalletBase?> refreshWallet(String walletId);

  /// Add a new wallet connection.
  /// Returns true if successful, throws on error.
  Future<bool> addWallet(String connectionString);

  /// Remove a wallet.
  Future<void> removeWallet(String walletId);

  /// Get transactions for a specific wallet.
  Future<List<WalletTransactionBase>> getTransactions(
    String walletId, {
    int? limit,
    int? offset,
  });

  /// Check if the connection string is valid for this provider.
  bool canHandle(String connectionString);

  /// Whether this provider is currently loading.
  bool get isLoading;

  /// Total balance across all wallets of this type.
  int get totalBalance;

  /// Pay a lightning invoice from the specified wallet.
  Future<WalletTransactionBase?> payLightningInvoice(
    String walletId,
    String invoice,
  );

  /// Create a lightning invoice and return the bolt11 string.
  Future<String?> createInvoice(
    String walletId,
    int amountSats,
    String? description,
  );

  /// Create a lightning invoice and return the full transaction details.
  Future<WalletTransactionBase?> createInvoiceWithTransaction(
    String walletId,
    int amountSats,
    String? description,
  );

  /// Register a callback invoked when wallets managed by this provider change
  /// (balance updated, wallet added/removed, connection state changed, etc.).
  ///
  /// The callback receives the updated list of wallets from this provider.
  /// Only one callback can be active at a time; calling this again replaces
  /// the previous callback.
  void setOnWalletsChanged(void Function(List<WalletBase> wallets) callback);

  /// Dispose internal listeners and resources.
  ///
  /// Call this when the provider is no longer needed (e.g., in controller's
  /// `onClose`).
  void dispose();
}
