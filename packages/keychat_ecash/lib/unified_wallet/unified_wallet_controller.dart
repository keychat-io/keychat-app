import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/unified_wallet/providers/cashu_wallet_provider.dart';
import 'package:keychat_ecash/unified_wallet/providers/nwc_wallet_provider.dart';
import 'package:keychat_ecash/unified_wallet/providers/wallet_provider.dart';

/// Unified controller for managing multiple wallet types
class UnifiedWalletController extends GetxController {
  /// All registered wallet providers
  final List<WalletProvider> _providers = [];

  /// All wallets from all providers
  final RxList<WalletBase> wallets = <WalletBase>[].obs;

  /// Currently selected wallet index
  final RxInt selectedIndex = 0.obs;

  /// Global loading state
  final RxBool isLoading = true.obs;

  /// Transactions for the currently selected wallet
  final RxList<WalletTransactionBase> transactions =
      <WalletTransactionBase>[].obs;

  /// Whether transactions are loading
  final RxBool isTransactionsLoading = false.obs;

  /// Whether there are more transactions to load
  final RxBool hasMoreTransactions = true.obs;

  /// Whether loading more transactions
  final RxBool isLoadingMore = false.obs;

  /// Page size for transaction pagination
  static const int _pageSize = 20;

  /// Get the currently selected wallet (null if none)
  WalletBase? get selectedWallet {
    if (selectedIndex.value < 0 || selectedIndex.value >= wallets.length) {
      return null;
    }
    return wallets[selectedIndex.value];
  }

  /// Total balance across all wallets
  int get totalBalance {
    return wallets.fold<int>(0, (sum, wallet) => sum + wallet.balanceSats);
  }

  @override
  void onInit() {
    super.onInit();
    _initProviders();
  }

  /// Initialize all wallet providers
  void _initProviders() {
    // Register built-in providers
    _providers.add(CashuWalletProvider());
    _providers.add(NwcWalletProvider());

    // Initial load
    loadAllWallets();
  }

  /// Register a new wallet provider (for future extensibility)
  void registerProvider(WalletProvider provider) {
    _providers.add(provider);
    loadAllWallets();
  }

  /// Load wallets from all providers
  Future<void> loadAllWallets() async {
    isLoading.value = true;
    try {
      final allWallets = <WalletBase>[];

      for (final provider in _providers) {
        try {
          final providerWallets = await provider.getWallets();
          logger.i(
            'Loaded ${providerWallets.length} wallets from ${provider.protocol}',
          );

          allWallets.addAll(providerWallets);
        } catch (e, s) {
          logger.e(
            'Failed to load wallets from ${provider.protocol}',
            error: e,
            stackTrace: s,
          );
        }
      }
      wallets.value = allWallets;

      // Ensure selected index is valid
      if (selectedIndex.value >= wallets.length) {
        selectedIndex.value = wallets.isEmpty ? 0 : wallets.length - 1;
      }

      // Load transactions for selected wallet
      if (wallets.isNotEmpty) {
        await loadTransactionsForSelected();
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh all wallet data
  Future<void> refreshAll() async {
    isLoading.value = true;
    try {
      // Refresh all providers in parallel
      await Future.wait(_providers.map((p) => p.refresh()));
      await loadAllWallets();
    } finally {
      isLoading.value = false;
    }
  }

  /// Select a wallet by index
  void selectWallet(int index) {
    if (index < 0 || index >= wallets.length) return;
    selectedIndex.value = index;
    loadTransactionsForSelected();
  }

  /// Load transactions for the currently selected wallet
  Future<void> loadTransactionsForSelected({int limit = _pageSize}) async {
    final wallet = selectedWallet;
    if (wallet == null) {
      transactions.clear();
      hasMoreTransactions.value = false;
      return;
    }

    isTransactionsLoading.value = true;
    hasMoreTransactions.value = true;
    try {
      final provider = _getProviderForProtocol(wallet.protocol);
      if (provider == null) {
        transactions.clear();
        hasMoreTransactions.value = false;
        return;
      }

      final txList = await provider.getTransactions(
        wallet.id,
        limit: limit,
      );
      transactions.value = txList;
      hasMoreTransactions.value = txList.length >= limit;
    } catch (e, s) {
      logger.e('Failed to load transactions', error: e, stackTrace: s);
      transactions.clear();
      hasMoreTransactions.value = false;
    } finally {
      isTransactionsLoading.value = false;
    }
  }

  /// Load more transactions (pagination)
  Future<void> loadMoreTransactions() async {
    if (isLoadingMore.value || !hasMoreTransactions.value) return;

    final wallet = selectedWallet;
    if (wallet == null) return;

    final provider = _getProviderForProtocol(wallet.protocol);
    if (provider == null) return;

    isLoadingMore.value = true;
    try {
      final txList = await provider.getTransactions(
        wallet.id,
        limit: _pageSize,
        offset: transactions.length,
      );

      if (txList.isEmpty) {
        hasMoreTransactions.value = false;
      } else {
        transactions.addAll(txList);
        hasMoreTransactions.value = txList.length >= _pageSize;
      }
    } catch (e, s) {
      logger.e('Failed to load more transactions', error: e, stackTrace: s);
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Add a new wallet by detecting the type from the connection string
  Future<bool> addWallet(String connectionString) async {
    // Find the appropriate provider
    WalletProvider? matchingProvider;
    for (final provider in _providers) {
      if (provider.canHandle(connectionString)) {
        matchingProvider = provider;
        break;
      }
    }

    if (matchingProvider == null) {
      EasyLoading.showError('Unsupported wallet type');
      return false;
    }

    try {
      EasyLoading.show(status: 'Adding wallet...');
      await matchingProvider.addWallet(connectionString);
      await loadAllWallets();
      EasyLoading.showSuccess('Wallet added');
      return true;
    } catch (e, s) {
      logger.e('Failed to add wallet', error: e, stackTrace: s);
      EasyLoading.showError('Failed to add wallet: $e');
      return false;
    }
  }

  /// Remove a wallet
  Future<void> removeWallet(WalletBase wallet) async {
    final provider = _getProviderForProtocol(wallet.protocol);
    if (provider == null) return;

    try {
      EasyLoading.show(status: 'Removing wallet...');
      await provider.removeWallet(wallet.id);
      await loadAllWallets();
      EasyLoading.showSuccess('Wallet removed');
    } catch (e, s) {
      logger.e('Failed to remove wallet', error: e, stackTrace: s);
      EasyLoading.showError('Failed to remove wallet: $e');
    }
  }

  /// Get provider for a specific protocol
  WalletProvider? _getProviderForProtocol(WalletProtocol protocol) {
    return _providers.firstWhereOrNull((p) => p.protocol == protocol);
  }

  /// Detect wallet type from connection string
  WalletProtocol? detectWalletType(String connectionString) {
    for (final provider in _providers) {
      if (provider.canHandle(connectionString)) {
        return provider.protocol;
      }
    }
    return null;
  }

  /// Get wallets filtered by protocol
  List<WalletBase> getWalletsByProtocol(WalletProtocol protocol) {
    return wallets.where((w) => w.protocol == protocol).toList();
  }

  /// Get balance by protocol type
  int getBalanceByProtocol(WalletProtocol protocol) {
    return wallets
        .where((w) => w.protocol == protocol)
        .fold<int>(0, (sum, w) => sum + w.balanceSats);
  }
}
