import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';

/// Abstract interface for wallet data providers
/// Each wallet protocol should implement this interface
abstract class WalletProvider {
  /// The protocol type this provider handles
  WalletProtocol get protocol;

  /// Get all wallets managed by this provider
  Future<List<WalletBase>> getWallets();

  /// Refresh wallet data (balances, etc.)
  Future<void> refresh();

  /// Refresh a specific wallet's data (balance, transactions)
  /// Returns the updated wallet
  Future<WalletBase?> refreshWallet(String walletId);

  /// Add a new wallet connection
  /// Returns true if successful, throws on error
  Future<bool> addWallet(String connectionString);

  /// Remove a wallet
  Future<void> removeWallet(String walletId);

  /// Get transactions for a specific wallet
  Future<List<WalletTransactionBase>> getTransactions(
    String walletId, {
    int? limit,
    int? offset,
  });

  /// Check if the connection string is valid for this provider
  bool canHandle(String connectionString);

  /// Whether this provider is currently loading
  bool get isLoading;

  /// Total balance across all wallets of this type
  int get totalBalance;
}
