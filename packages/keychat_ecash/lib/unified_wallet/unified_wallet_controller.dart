import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart'
    show BorderRadius, Clip, Curves, Radius, RoundedRectangleBorder;
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

  /// Carousel controller for programmatic page navigation (desktop arrows).
  final CarouselSliderController carouselController =
      CarouselSliderController();

  /// The wallet ID that should be selected.
  ///
  /// Used to restore selection after wallets are re-sorted or arrive late.
  String? _selectedWalletId;

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
  ///
  /// When a wallet's balance changes, its transaction cache is invalidated
  /// and — if it is the currently selected wallet — the transaction list is
  /// reloaded automatically so the UI stays up-to-date after payments or
  /// receives.
  void _onProviderWalletsChanged(
    WalletProtocol protocol,
    List<WalletBase> updatedWallets,
  ) {
    try {
      // Quick check: skip if the wallet set for this protocol hasn't changed
      final existing = wallets.where((w) => w.protocol == protocol).toList();
      if (_walletsEqual(existing, updatedWallets)) return;

      // Determine which wallets had a balance change so we can invalidate
      // their transaction cache.
      final existingById = {for (final w in existing) w.id: w};
      var selectedWalletAffected = false;
      for (final updated in updatedWallets) {
        final old = existingById[updated.id];
        if (old == null || old.balanceSats != updated.balanceSats) {
          _transactionCache.remove(updated.id);
          if (updated.id == _selectedWalletId) {
            selectedWalletAffected = true;
          }
        }
      }

      final merged = <WalletBase>[
        ...wallets.where((w) => w.protocol != protocol),
        ...updatedWallets,
      ];
      merged.sort((a, b) => b.balanceSats.compareTo(a.balanceSats));
      wallets.value = merged;

      _syncSelectedIndex();

      // Reload transactions for the selected wallet if its balance changed
      if (selectedWalletAffected) {
        unawaited(loadTransactionsForSelected(forceRefresh: true));
      }
    } catch (e) {
      logger.e('Failed to update $protocol wallets in list: $e');
    }
  }

  /// Compares two wallet lists by ID, balance, and displayName for equality.
  static bool _walletsEqual(List<WalletBase> a, List<WalletBase> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].balanceSats != b[i].balanceSats ||
          a[i].displayName != b[i].displayName) {
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

  /// Initialize wallets and restore saved selection.
  ///
  /// Skips transaction loading in [loadAllWallets] because
  /// [_restoreSavedWalletSelection] will load transactions for the
  /// correct (previously saved) wallet, avoiding a wasted fetch for
  /// whatever wallet happens to be at index 0.
  Future<void> _initializeWallets() async {
    await loadAllWallets(loadTransactions: false);
    await _restoreSavedWalletSelection();
  }

  /// Restore the previously saved wallet selection.
  Future<void> _restoreSavedWalletSelection() async {
    try {
      final savedWallet = await WalletStorageSelection.loadWallet();
      _selectedWalletId = savedWallet.id;
      _syncSelectedIndex();
      if (wallets.isNotEmpty) {
        await loadTransactionsForSelected();
      }
    } catch (e, s) {
      logger.e('Failed to restore saved wallet', error: e, stackTrace: s);
    }
  }

  /// Derive [selectedIndex] from [_selectedWalletId].
  ///
  /// This is the **only** place that writes to [selectedIndex]. Every code
  /// path that changes [_selectedWalletId] or [wallets] should call this.
  void _syncSelectedIndex() {
    if (wallets.isEmpty) {
      selectedIndex.value = 0;
      return;
    }
    if (_selectedWalletId != null) {
      final index = wallets.indexWhere((w) => w.id == _selectedWalletId);
      if (index != -1) {
        selectedIndex.value = index;
        return;
      }
    }
    // Wallet not (yet) in the list — clamp to valid range
    selectedIndex.value = selectedIndex.value.clamp(0, wallets.length - 1);
  }

  /// Load wallets from all providers in parallel.
  ///
  /// Each provider loads independently. Results are collected into local lists
  /// first, then merged into the unified [wallets] list in a single batch to
  /// avoid concurrent modification of the RxList.
  Future<void> loadAllWallets({bool loadTransactions = true}) async {
    isLoading.value = true;
    try {
      // Load all providers in parallel, each with a 10s timeout
      final results = <WalletProtocol, List<WalletBase>>{};
      await Future.wait(
        _providers.map((provider) async {
          try {
            final providerWallets = await provider
                .getWallets()
                .timeout(const Duration(seconds: 10));
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
        }),
      );

      // Merge all results into the wallets list in a single batch
      final merged = <WalletBase>[
        // Keep wallets whose protocol was not reloaded (shouldn't happen, but safe)
        ...wallets.where((w) => !results.containsKey(w.protocol)),
        // Add freshly loaded wallets
        for (final entry in results.values) ...entry,
      ]..sort((a, b) => b.balanceSats.compareTo(a.balanceSats));
      wallets.value = merged;

      _syncSelectedIndex();

      // Load transactions for selected wallet
      if (loadTransactions && wallets.isNotEmpty) {
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
  ///
  /// The provider's `refreshWallet` updates the balance, which may trigger the
  /// reactive worker ([_onProviderWalletsChanged]) to reload transactions
  /// automatically. To avoid a redundant second fetch we only reload
  /// transactions explicitly when the cache was NOT already repopulated by
  /// the worker.
  Future<void> refreshSelectedWallet([WalletBase? wallet]) async {
    final targetWallet = wallet ?? selectedWallet;

    final provider = _getProviderForProtocol(targetWallet.protocol);
    if (provider == null) return;

    try {
      // Invalidate cached transactions for this wallet
      _transactionCache.remove(targetWallet.id);

      // Refresh the provider's data for this wallet and get updated wallet.
      // This may trigger the reactive worker (_onProviderWalletsChanged) which
      // will repopulate the cache and update the UI if the balance changed.
      final updatedWallet = await provider.refreshWallet(targetWallet.id);

      // Update the wallet in the list if refresh was successful
      if (updatedWallet != null) {
        final index = wallets.indexWhere((w) => w.id == targetWallet.id);
        if (index != -1) {
          wallets[index] = updatedWallet;
        }
      }

      // Only reload transactions if the reactive worker hasn't already done so
      // (i.e. cache is still empty for this wallet).
      if (!_transactionCache.containsKey(targetWallet.id)) {
        await loadTransactionsForSelected(wallet: targetWallet);
      }
    } catch (e, s) {
      logger.e('Failed to refresh selected wallet', error: e, stackTrace: s);
    }
  }

  /// Select a wallet by index and save the selection.
  ///
  /// When [fromCarousel] is false (e.g. tapping a card or restoring saved
  /// selection), the carousel is animated to the new page so the selected
  /// card is always visible / centered.
  Future<void> selectWallet(int index, {bool fromCarousel = false}) async {
    if (wallets.isEmpty) return;
    if (index == selectedIndex.value) return;

    // Clamp index to valid range, update the single source of truth
    final validIndex = index.clamp(0, wallets.length - 1);
    _selectedWalletId = wallets[validIndex].id;
    _syncSelectedIndex();

    // Sync carousel position when the change didn't originate from a swipe
    if (!fromCarousel) {
      carouselController.animateToPage(
        validIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    await WalletStorageSelection.saveWallet(selectedWallet);
    await loadTransactionsForSelected();
  }

  /// Load transactions for the currently selected wallet.
  ///
  /// Returns cached transactions when available, unless [forceRefresh] is set.
  /// If [wallet] is provided, load transactions for that wallet instead.
  /// When the target wallet differs from the currently selected wallet, only
  /// the cache is updated — the visible [transactions] list is left untouched
  /// so the UI keeps showing the correct wallet's data.
  Future<void> loadTransactionsForSelected({
    int limit = _pageSize,
    WalletBase? wallet,
    bool forceRefresh = false,
  }) async {
    final targetWallet = wallet ?? selectedWallet;
    final isSelectedWallet =
        wallet == null || targetWallet.id == selectedWallet.id;

    // Return cached transactions if available and not forcing refresh
    if (!forceRefresh) {
      final cached = _transactionCache[targetWallet.id];
      if (cached != null) {
        if (isSelectedWallet) {
          transactions.value = cached;
        }
        hasMoreTransactions.value = cached.length >= limit;
        return;
      }
    }

    if (isSelectedWallet) {
      isTransactionsLoading.value = true;
    }
    hasMoreTransactions.value = true;
    try {
      final provider = _getProviderForProtocol(targetWallet.protocol);
      if (provider == null) {
        if (isSelectedWallet) {
          transactions.clear();
        }
        hasMoreTransactions.value = false;
        return;
      }

      final txList = await provider.getTransactions(
        targetWallet.id,
        limit: limit,
      );
      _transactionCache[targetWallet.id] = txList;
      if (isSelectedWallet) {
        transactions.value = txList;
      }
      hasMoreTransactions.value = txList.length >= limit;
    } catch (e, s) {
      logger.e('Failed to load transactions', error: e, stackTrace: s);
      if (isSelectedWallet) {
        transactions.clear();
      }
      hasMoreTransactions.value = false;
    } finally {
      if (isSelectedWallet) {
        isTransactionsLoading.value = false;
      }
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
      // loadAllWallets calls provider.getWallets() which fetches fresh data.
      // Skipping provider.refresh() here avoids a double transaction load
      // from the reactive worker.
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
      _selectedWalletId = null;
      await provider.removeWallet(wallet.id);
      await loadAllWallets();
      await EasyLoading.showSuccess('Wallet removed');
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

  // ============================================================
  // Unified Payment APIs
  // ============================================================

  /// Pay a lightning invoice.
  ///
  /// Uses the wallet identified by [walletId]. Falls back to [selectedWallet]
  /// when [walletId] is omitted.
  ///
  /// Returns [WalletTransactionBase] on success, null on failure or
  /// cancellation.
  Future<WalletTransactionBase?> payLightningInvoiceWithWallet(
    String walletId,
    String invoice,
  ) async {
    final wallet = wallets.firstWhereOrNull((w) => w.id == walletId);
    if (wallet == null) {
      await EasyLoading.showError('Wallet not found');
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
      // The provider's internal balance refresh triggers the reactive
      // worker (_onProviderWalletsChanged) which invalidates the cache
      // and reloads transactions. For protocols that don't update
      // balance reactively, refreshSelectedWallet handles it.
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
      // Refresh transactions so the new pending invoice appears in the list
      unawaited(refreshSelectedWallet());
    }
    return res;
  }
}
