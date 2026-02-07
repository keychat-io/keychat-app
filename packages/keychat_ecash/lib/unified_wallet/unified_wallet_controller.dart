import 'dart:async';

import 'package:flutter/material.dart'
    show BorderRadius, Clip, Radius, RoundedRectangleBorder;
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat_ecash/CreateInvoice/CreateInvoice_page.dart';
import 'package:keychat_ecash/keychat_ecash.dart' show MintBalanceClass;
import 'package:keychat_ecash/unified_wallet/index.dart';
import 'package:keychat_ecash/wallet_selection_storage.dart';

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

  /// Per-wallet transaction cache, keyed by wallet ID.
  ///
  /// Avoids re-fetching from the provider when switching between wallets.
  /// Cleared on explicit refresh via [refreshAll] or [refreshSelectedWallet].
  final Map<String, List<WalletTransactionBase>> _transactionCache = {};

  /// Get the currently selected wallet (null if none)
  WalletBase get selectedWallet {
    if (wallets.isEmpty) {
      return CashuWallet(
        mintBalance: MintBalanceClass(
          KeychatGlobal.defaultCashuMintURL,
          'sat',
          0,
        ),
        supportsMint: false,
        supportsMelt: false,
      );
    }
    if (selectedIndex.value < 0 || selectedIndex.value >= wallets.length) {
      return wallets[0];
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

  /// Ensures the controller is fully initialized before use.
  ///
  /// Call this method when you need to wait for all providers to be ready.
  /// Returns immediately if wallets are already loaded.
  Future<void> ensureInitialized() async {
    // Already initialized - return immediately
    if (!isLoading.value && wallets.isNotEmpty) return;

    // Set up the completion listener BEFORE triggering load to avoid race
    final completer = Completer<void>();
    late Worker worker;
    Timer? timeoutTimer;

    worker = ever(isLoading, (bool loading) {
      if (!loading && !completer.isCompleted) {
        timeoutTimer?.cancel();
        worker.dispose();
        completer.complete();
      }
    });

    // If not loading and wallets are empty, trigger a load
    if (!isLoading.value && wallets.isEmpty) {
      unawaited(loadAllWallets());
    }

    // Check again after registering worker — loading may have already
    // completed between the initial check and the worker registration.
    if (!isLoading.value && wallets.isNotEmpty) {
      timeoutTimer?.cancel();
      worker.dispose();
      if (!completer.isCompleted) completer.complete();
      return completer.future;
    }

    // Timeout after 15 seconds
    timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        worker.dispose();
        completer.complete();
      }
    });

    return completer.future;
  }

  /// Initialize all wallet providers and set up reactive callbacks.
  void _initProviders() {
    // Register built-in providers
    _providers.add(CashuWalletProvider());
    _providers.add(NwcWalletProvider());
    _providers.add(LndWalletProvider());

    // Set up unified balance change callbacks for each provider
    for (final provider in _providers) {
      provider.setOnWalletsChanged((updatedWallets) {
        _onProviderWalletsChanged(provider.protocol, updatedWallets);
      });
    }

    // Initial load and restore saved wallet selection
    _initializeWallets();
  }

  /// Handle wallet changes from a specific provider.
  ///
  /// Replaces all wallets of the given [protocol] in the unified list with
  /// [updatedWallets], preserving wallets from other protocols.
  /// Skips the update entirely when the wallet set hasn't changed (same IDs
  /// and balances) to avoid unnecessary sort + UI rebuild.
  void _onProviderWalletsChanged(
    WalletProtocol protocol,
    List<WalletBase> updatedWallets,
  ) {
    try {
      // Quick check: skip if the wallet set for this protocol hasn't changed
      final existing = wallets.where((w) => w.protocol == protocol).toList();
      if (_walletsEqual(existing, updatedWallets)) return;

      final merged = <WalletBase>[
        ...wallets.where((w) => w.protocol != protocol),
        ...updatedWallets,
      ];
      merged.sort((a, b) => b.balanceSats.compareTo(a.balanceSats));
      wallets.value = merged;
    } catch (e) {
      logger.e('Failed to update $protocol wallets in list: $e');
    }
  }

  /// Compares two wallet lists by ID and balance for equality.
  static bool _walletsEqual(List<WalletBase> a, List<WalletBase> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].balanceSats != b[i].balanceSats) {
        return false;
      }
    }
    return true;
  }

  @override
  void onClose() {
    for (final provider in _providers) {
      provider.dispose();
    }
    super.onClose();
  }

  /// Initialize wallets and restore saved selection
  Future<void> _initializeWallets() async {
    await loadAllWallets();
    await _restoreSavedWalletSelection();
  }

  /// Restore the previously saved wallet selection
  Future<void> _restoreSavedWalletSelection() async {
    try {
      final savedWallet = await WalletStorageSelection.loadWallet();
      final index = wallets.indexWhere((w) => w.id == savedWallet.id);
      if (index != -1) {
        selectedIndex.value = index;
        await loadTransactionsForSelected();
      }
    } catch (e, s) {
      logger.e('Failed to restore saved wallet', error: e, stackTrace: s);
    }
  }

  /// Register a new wallet provider (for future extensibility)
  void registerProvider(WalletProvider provider) {
    _providers.add(provider);
    loadAllWallets();
  }

  /// Load wallets from all providers in parallel.
  ///
  /// Each provider loads independently. Results are collected into local lists
  /// first, then merged into the unified [wallets] list in a single batch to
  /// avoid concurrent modification of the RxList.
  Future<void> loadAllWallets() async {
    isLoading.value = true;
    try {
      final currentWalletId = selectedWallet.id;

      // Load all providers in parallel, collect results into local map
      final results = <WalletProtocol, List<WalletBase>>{};
      await Future.wait(_providers.map((provider) async {
        try {
          final providerWallets = await provider.getWallets();
          logger.i(
            'Loaded ${providerWallets.length} wallets from ${provider.protocol}',
          );
          results[provider.protocol] = providerWallets;
        } catch (e, s) {
          logger.e(
            'Failed to load wallets from ${provider.protocol}',
            error: e,
            stackTrace: s,
          );
        }
      }));

      // Merge all results into the wallets list in a single batch
      final merged = <WalletBase>[
        // Keep wallets whose protocol was not reloaded (shouldn't happen, but safe)
        ...wallets.where((w) => !results.containsKey(w.protocol)),
        // Add freshly loaded wallets
        for (final entry in results.values) ...entry,
      ];
      merged.sort((a, b) => b.balanceSats.compareTo(a.balanceSats));
      wallets.value = merged;

      // Restore selection
      final newIndex = wallets.indexWhere((w) => w.id == currentWalletId);
      if (newIndex != -1) {
        selectedIndex.value = newIndex;
      } else {
        _ensureValidSelectedIndex();
      }

      // Load transactions for selected wallet
      if (wallets.isNotEmpty) {
        await loadTransactionsForSelected();
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh all wallet data.
  ///
  /// Clears the transaction cache, refreshes each provider's underlying data,
  /// then reloads all wallets. [loadAllWallets] handles its own isLoading state.
  Future<void> refreshAll() async {
    _transactionCache.clear();
    await Future.wait(_providers.map((p) => p.refresh()));
    await loadAllWallets();
  }

  WalletBase? getWalletById(String uri) {
    return wallets.firstWhereOrNull((w) => w.id == uri);
  }

  /// Refresh only the currently selected wallet's balance and transactions.
  /// If [wallet] is provided, refresh that wallet instead of the selected one.
  Future<void> refreshSelectedWallet([WalletBase? wallet]) async {
    final targetWallet = wallet ?? selectedWallet;

    final provider = _getProviderForProtocol(targetWallet.protocol);
    if (provider == null) return;

    try {
      // Invalidate cached transactions for this wallet
      _transactionCache.remove(targetWallet.id);

      // Refresh the provider's data for this wallet and get updated wallet
      final updatedWallet = await provider.refreshWallet(targetWallet.id);

      // Update the wallet in the list if refresh was successful
      if (updatedWallet != null) {
        final index = wallets.indexWhere((w) => w.id == targetWallet.id);
        if (index != -1) {
          wallets[index] = updatedWallet;
        }
      }

      // Reload transactions for the target wallet (cache was cleared above)
      await loadTransactionsForSelected(wallet: targetWallet);
    } catch (e, s) {
      logger.e('Failed to refresh selected wallet', error: e, stackTrace: s);
    }
  }

  /// Select a wallet by index and save the selection
  Future<void> selectWallet(int index) async {
    if (wallets.isEmpty) return;
    if (index == selectedIndex.value) return;

    // Clamp index to valid range
    final validIndex = index.clamp(0, wallets.length - 1);
    selectedIndex.value = validIndex;

    // Save the selection to storage
    final wallet = selectedWallet;
    await WalletStorageSelection.saveWallet(wallet);
    await loadTransactionsForSelected();
  }

  /// Load transactions for the currently selected wallet.
  ///
  /// Returns cached transactions when available, unless [forceRefresh] is set.
  /// If [wallet] is provided, load transactions for that wallet instead.
  Future<void> loadTransactionsForSelected({
    int limit = _pageSize,
    WalletBase? wallet,
    bool forceRefresh = false,
  }) async {
    final targetWallet = wallet ?? selectedWallet;

    // Return cached transactions if available and not forcing refresh
    if (!forceRefresh) {
      final cached = _transactionCache[targetWallet.id];
      if (cached != null) {
        transactions.value = cached;
        hasMoreTransactions.value = cached.length >= limit;
        return;
      }
    }

    isTransactionsLoading.value = true;
    hasMoreTransactions.value = true;
    try {
      final provider = _getProviderForProtocol(targetWallet.protocol);
      if (provider == null) {
        transactions.clear();
        hasMoreTransactions.value = false;
        return;
      }

      final txList = await provider.getTransactions(
        targetWallet.id,
        limit: limit,
      );
      transactions.value = txList;
      _transactionCache[targetWallet.id] = txList;
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
      // Update cache with full accumulated list
      _transactionCache[wallet.id] = transactions.toList();
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
      await EasyLoading.showError('Unsupported wallet type');
      return false;
    }

    try {
      await EasyLoading.show(status: 'Adding wallet...');
      await matchingProvider.addWallet(connectionString);
      await matchingProvider.refresh();
      await loadAllWallets();
      await EasyLoading.showSuccess('Wallet added');
      return true;
    } catch (e, s) {
      logger.e('Failed to add wallet', error: e, stackTrace: s);
      await EasyLoading.showError(e.toString());
      return false;
    }
  }

  /// Remove a wallet
  Future<void> removeWallet(WalletBase wallet) async {
    final provider = _getProviderForProtocol(wallet.protocol);
    if (provider == null) return;

    try {
      await EasyLoading.show(status: 'Removing wallet...');
      selectedIndex.value = 0;
      await provider.removeWallet(wallet.id);
      await loadAllWallets();
      await EasyLoading.showSuccess('Wallet removed');
    } catch (e, s) {
      logger.e('Failed to remove wallet', error: e, stackTrace: s);
      EasyLoading.showError('Failed to remove wallet: $e');
    }
  }

  /// Ensure selected index is within valid range
  void _ensureValidSelectedIndex() {
    if (wallets.isEmpty) {
      selectedIndex.value = 0;
    } else if (selectedIndex.value < 0) {
      selectedIndex.value = 0;
    } else if (selectedIndex.value >= wallets.length) {
      selectedIndex.value = wallets.length - 1;
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

  // ============================================================
  // Unified Payment APIs
  // ============================================================

  /// Pay a lightning invoice using the currently selected wallet.
  ///
  /// Returns [WalletTransactionBase] on success, null on failure or cancellation.
  /// The returned type will be [CashuWalletTransaction] or [NwcWalletTransaction]
  /// depending on the selected wallet protocol.
  Future<WalletTransactionBase?> payLightningInvoice(String invoice) async {
    final wallet = selectedWallet;

    final provider = _getProviderForProtocol(wallet.protocol);
    if (provider == null) {
      await EasyLoading.showError('Wallet provider not found');
      return null;
    }

    final result = await provider.payLightningInvoice(wallet.id, invoice);
    if (result != null) {
      await HapticFeedback.mediumImpact();
      unawaited(refreshSelectedWallet(getWalletById(wallet.id)));
    }
    return result;
  }

  /// Pay a lightning invoice using a specific wallet.
  ///
  /// [walletId] - The wallet ID to use for payment
  /// [invoice] - The lightning invoice string (lnbc...)
  Future<WalletTransactionBase?> payLightningInvoiceWithWallet(
    String walletId,
    String invoice,
  ) async {
    final wallet = wallets.firstWhereOrNull((w) => w.id == walletId);
    if (wallet == null) {
      EasyLoading.showError('Wallet not found');
      return null;
    }

    final provider = _getProviderForProtocol(wallet.protocol);
    if (provider == null) {
      await EasyLoading.showError('Wallet provider not found');
      return null;
    }

    final result = await provider.payLightningInvoice(walletId, invoice);
    if (result != null) {
      await HapticFeedback.mediumImpact();
      unawaited(refreshSelectedWallet(wallet));
    }
    return result;
  }

  /// Create a lightning invoice and return full transaction details.
  ///
  /// This is useful when you need the full transaction object for UI display.
  /// Returns [WalletTransactionBase] on success, null on failure.
  Future<WalletTransactionBase?> createInvoiceWithTransaction(
    int amountSats, {
    String? description,
  }) async {
    final wallet = selectedWallet;

    final provider = _getProviderForProtocol(wallet.protocol);
    if (provider == null) {
      await EasyLoading.showError('Wallet provider not found');
      return null;
    }

    return provider.createInvoiceWithTransaction(
      wallet.id,
      amountSats,
      description,
    );
  }

  Future<WalletTransactionBase?> dialogToMakeInvoice({
    int? amount,
    String? description,
  }) async {
    final res = await Get.bottomSheet<WalletTransactionBase?>(
      ignoreSafeArea: false,
      isScrollControlled: GetPlatform.isMobile,
      clipBehavior: Clip.hardEdge,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      CreateInvoicePage(amount: amount, description: description),
    );
    if (res != null) {
      await HapticFeedback.mediumImpact();
    }
    return res;
  }
}
