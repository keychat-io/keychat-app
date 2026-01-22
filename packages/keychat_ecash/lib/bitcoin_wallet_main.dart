import 'package:carousel_slider/carousel_slider.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/service/qrscan.service.dart';
import 'package:keychat_ecash/Bills/cashu_transaction.dart';
import 'package:keychat_ecash/EcashSetting/EcashSetting_bindings.dart';
import 'package:keychat_ecash/EcashSetting/EcashSetting_page.dart';
import 'package:keychat_ecash/EcashSetting/MintServerPage.dart';
import 'package:keychat_ecash/cashu_send.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/nwc/nwc_setting_page.dart';
import 'package:keychat_ecash/unified_wallet/index.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:ndk/ndk.dart';

class BitcoinWalletMain extends StatefulWidget {
  const BitcoinWalletMain({super.key});

  @override
  State<BitcoinWalletMain> createState() => _BitcoinWalletMainState();
}

class _BitcoinWalletMainState extends State<BitcoinWalletMain> {
  late UnifiedWalletController controller;

  @override
  void initState() {
    super.initState();
    controller = Utils.getOrPutGetxController(
      create: UnifiedWalletController.new,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Bitcoin Wallets'),
        actions: [
          IconButton(
            onPressed: () async {
              await controller.refreshAll();
              await EasyLoading.showSuccess('Refreshed');
            },
            icon: const Icon(CupertinoIcons.refresh),
          ),
          IconButton(
            onPressed: () {
              QrScanService.instance.handleQRScan(autoProcess: true);
            },
            icon: const Icon(CupertinoIcons.qrcode_viewfinder),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
      body: DesktopContainer(
        child: Obx(() {
          if (controller.isLoading.value && controller.wallets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return CustomRefreshIndicator(
            onRefresh: _handleRefresh,
            trigger: IndicatorTrigger.bothEdges,
            builder: (context, child, indicatorController) {
              // Track current side for onRefresh callback
              _currentIndicatorSide = indicatorController.side;
              return Stack(
                children: [
                  child,
                  // Top refresh indicator
                  if (indicatorController.side == IndicatorSide.top)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildRefreshIndicator(indicatorController),
                    ),
                  // Bottom load more indicator
                  if (indicatorController.side == IndicatorSide.bottom)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildLoadMorePullIndicator(indicatorController),
                    ),
                ],
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Total Balance Section
                _buildTotalBalanceSection(context),
                // Wallet Cards Carousel
                _buildWalletCarousel(context),
                // Transactions Section
                _buildTransactionsHeader(context),
                // Transaction List
                _buildTransactionsList(context),
                const SizedBox(height: 40),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Current indicator side for determining refresh action
  IndicatorSide? _currentIndicatorSide;

  /// Handle refresh based on trigger direction
  Future<void> _handleRefresh() async {
    if (_currentIndicatorSide == IndicatorSide.top) {
      // Pull down - refresh all
      await controller.refreshAll();
    } else if (_currentIndicatorSide == IndicatorSide.bottom) {
      // Pull up - load more
      await controller.loadMoreTransactions();
    }
  }

  void _navigateToSettings() {
    Get.to<void>(
      () => const EcashSettingPage(),
      binding: EcashSettingBindings(),
      id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
    );
  }

  /// Bottom action bar with protocol-specific actions
  Widget _buildBottomBar(BuildContext context) {
    return Obx(() {
      final wallet = controller.selectedWallet;
      final protocol = wallet.protocol;

      return SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: protocol == WalletProtocol.cashu
              ? _buildCashuActions(context)
              : _buildNwcActions(context),
        ),
      );
    });
  }

  /// Build Cashu wallet actions (3 buttons: Pay Ecash, Receive Ecash, More)
  Widget _buildCashuActions(BuildContext context) {
    // Pay uses red/orange tones, Receive uses green tones
    const payColor = Colors.redAccent;
    const receiveColor = Colors.green;

    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            icon: CupertinoIcons.arrow_up_right,
            label: 'Pay Ecash',
            color: payColor,
            onTap: _handlePayEcash,
            expanded: true,
          ),
        ),
        const SizedBox(width: 12),
        // Receive Ecash
        Expanded(
          child: _buildActionButton(
            context,
            icon: CupertinoIcons.arrow_down_left,
            label: 'Receive Ecash',
            color: receiveColor,
            onTap: _handleReceiveEcash,
            expanded: true,
          ),
        ),
        const SizedBox(width: 12),
        // More menu
        _buildActionButton(
          context,
          icon: CupertinoIcons.ellipsis_circle,
          label: GetPlatform.isDesktop ? 'More' : null,
          color: Colors.grey,
          onTap: _showMoreMenu,
        ),
      ],
    );
  }

  /// Show more menu with Lightning and Settings options
  void _showMoreMenu() {
    Get.bottomSheet<void>(
      CupertinoActionSheet(
        title: const Text('More Options'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Get.back<void>();
              _handlePayLightning();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.bolt, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('Pay to Lightning'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Get.back<void>();
              _handleReceiveLightning();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.bolt, color: Colors.green),
                SizedBox(width: 8),
                Text('Receive from Lightning'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Get.back<void>();
              _navigateToSettings();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.settings, color: Colors.grey),
                SizedBox(width: 8),
                Text('Settings'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Get.back<void>(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  /// Build NWC wallet actions (2 buttons)
  Widget _buildNwcActions(BuildContext context) {
    // Pay uses red/orange tones, Receive uses green tones
    const payColor = Colors.redAccent;
    const receiveColor = Colors.green;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            icon: CupertinoIcons.arrow_up_right,
            label: 'Pay Lightning',
            color: payColor,
            onTap: _handlePayLightning,
            expanded: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            context,
            icon: CupertinoIcons.arrow_down_left,
            label: 'Receive Lightning',
            color: receiveColor,
            onTap: _handleReceiveLightning,
            expanded: true,
          ),
        ),
        // const SizedBox(width: 16),
        // _buildActionButton(
        //   context,
        //   icon: CupertinoIcons.settings,
        //   label: 'Settings',
        //   color: Colors.grey,
        //   onTap: _navigateToSettings,
        // ),
      ],
    );
  }

  /// Build a single action button (for wide screens and NWC)
  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? label,
    bool expanded = false,
  }) {
    final button = Material(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              if (label != null) const SizedBox(width: 6),
              if (label != null)
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return expanded ? button : button;
  }

  Future<void> _handlePayEcash() async {
    final tx = await Get.bottomSheet<Transaction>(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      const PayEcashPage(),
    );
    if (tx == null) return;

    await Get.to<void>(
      () => CashuTransactionPage(
        transaction: tx,
      ),
      id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
    );
  }

  /// Handle Pay Lightning action
  Future<void> _handlePayLightning() async {
    final tx = await Get.find<EcashController>().dialogToPayInvoice();
    if (tx == null) return;

    // Handle NWC payment result
    if (tx.rawData is TransactionResult) {
      final nwcUri = tx.walletId ?? controller.selectedWallet.id;
      await Get.to<void>(
        () => UnifiedTransactionPage(
          nwcTransaction: tx.rawData as TransactionResult,
          walletId: nwcUri,
        ),
        id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
      );
      return;
    }

    // Handle Cashu Lightning payment result
    if (tx.rawData is Transaction) {
      await Get.to<void>(
        () => UnifiedTransactionPage(
          cashuTransaction: tx.rawData as Transaction,
          walletId: (tx.rawData as Transaction).mintUrl,
        ),
        id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
      );
    }
  }

  /// Handle Receive Lightning action
  Future<void> _handleReceiveLightning() async {
    final tx = await controller.dialogToMakeInvoice();
    if (tx == null) return;
    // Handle NWC invoice result
    if (tx.rawData is TransactionResult) {
      final nwcUri = tx.walletId ?? controller.selectedWallet.id;

      await Get.to<void>(
        () => UnifiedTransactionPage(
          nwcTransaction: tx.rawData as TransactionResult,
          walletId: nwcUri,
        ),
        id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
      );
      return;
    }
    // Handle Cashu Lightning invoice result
    if (tx.rawData is Transaction) {
      await Get.to<void>(
        () => UnifiedTransactionPage(
          cashuTransaction: tx.rawData as Transaction,
          walletId: (tx.rawData as Transaction).mintUrl,
        ),
        id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
      );
    }
  }

  Future<void> _handleReceiveEcash() async {
    final input = await Get.bottomSheet<String>(
      CupertinoActionSheet(
        title: const Text('Receive Ecash'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              final scanned = await QrScanService.instance.handleQRScan();
              if (scanned != null && scanned.isNotEmpty) {
                Get.back(result: scanned);
              }
            },
            child: const Text('Scan QR Code'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null && data!.text!.isNotEmpty) {
                Get.back(result: data.text);
              } else {
                EasyLoading.showError('Clipboard is empty');
              }
            },
            child: const Text('Paste from Clipboard'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Get.back<void>(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (input == null || input.isEmpty) return;
    await EcashUtils.handleReceiveToken(token: input);
  }

  /// Total balance display section
  Widget _buildTotalBalanceSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Wrap(
            direction: Axis.vertical,
            children: [
              const Text('Total Balance'),
              Obx(
                () => controller.isLoading.value
                    ? SizedBox(
                        height: 60,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      )
                    : RichText(
                        text: TextSpan(
                          text: controller.totalBalance.toString(),
                          children: const <TextSpan>[
                            TextSpan(
                              text: ' sat',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          style: TextStyle(
                            height: 1.3,
                            fontSize: 48,
                            color:
                                Theme.of(context).textTheme.titleLarge!.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Wallet cards carousel
  Widget _buildWalletCarousel(BuildContext context) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.only(left: 10),
        child: CarouselSlider(
          options: CarouselOptions(
            height: 160,
            padEnds: false,
            viewportFraction: GetPlatform.isDesktop ? 0.4 : 0.45,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              if (index < controller.wallets.length) {
                controller.selectWallet(index);
              }
            },
          ),
          items: [
            // Wallet cards
            ...controller.wallets.asMap().entries.map((entry) {
              final index = entry.key;
              final wallet = entry.value;
              return _buildWalletCard(context, wallet, index);
            }),
            // Add new wallet card
            _buildAddCard(context),
          ],
        ),
      ),
    );
  }

  /// Individual wallet card widget
  Widget _buildWalletCard(BuildContext context, WalletBase wallet, int index) {
    // Generate gradient colors based on wallet
    final gradientColors = _getWalletGradientColors(wallet);
    final isSelected = controller.selectedIndex.value == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await controller.selectWallet(index);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            // Always show border to prevent layout shift
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Protocol icon and badge
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        wallet.icon,
                        color: wallet.primaryColor,
                        size: 42,
                      ),
                      _buildProtocolBadge(wallet.protocol),
                    ],
                  ),
                ),
                // Wallet name/URL
                Text(
                  wallet.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color
                            ?.withAlpha(160),
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                // Balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (wallet.isBalanceLoading)
                      const SizedBox(
                        width: 60,
                        height: 28,
                        child: CupertinoActivityIndicator(),
                      )
                    else
                      RichText(
                        text: TextSpan(
                          text: wallet.balanceSats.toString(),
                          children: const <TextSpan>[
                            TextSpan(
                              text: ' sat',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                          style: TextStyle(
                            height: 1.3,
                            fontSize: 28,
                            color: Theme.of(context).textTheme.bodyLarge!.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: () => _onWalletCardTap(wallet),
                      icon: const Icon(CupertinoIcons.right_chevron),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Protocol badge widget
  Widget _buildProtocolBadge(WalletProtocol protocol) {
    final (label, color) = switch (protocol) {
      WalletProtocol.cashu => ('Cashu', KeychatGlobal.secondaryColor),
      WalletProtocol.nwc => ('NWC', KeychatGlobal.bitcoinColor),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Add wallet card
  Widget _buildAddCard(BuildContext context) {
    return GestureDetector(
      child: Container(
        width: MediaQuery.of(context).size.width / 2,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.onSurface.withAlpha(10),
              Theme.of(context).colorScheme.onSurface.withAlpha(40),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(CupertinoIcons.add_circled, size: 48),
              onPressed: () => _showAddWalletDialog(context),
            ),
            Text(
              'Add Wallet',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            textSmallGray(context, 'Cashu or NWC wallet'),
          ],
        ),
      ),
      onTap: () => _showAddWalletDialog(context),
    );
  }

  /// Transactions header
  Widget _buildTransactionsHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transactions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Obx(() {
                final wallet = controller.selectedWallet;
                return Text(
                  wallet.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color
                            ?.withAlpha(160),
                      ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// Transaction list widget
  Widget _buildTransactionsList(BuildContext context) {
    return Obx(() {
      if (controller.isTransactionsLoading.value &&
          controller.transactions.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (controller.transactions.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Wrap(
              direction: Axis.vertical,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 36,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                ),
                textSmallGray(context, 'No transactions'),
              ],
            ),
          ),
        );
      }

      return Column(
        children: [
          ...controller.transactions.map((transaction) {
            return _buildTransactionTile(context, transaction);
          }),
          // Load more / No more data indicator
          _buildLoadMoreIndicator(context),
        ],
      );
    });
  }

  /// Build top refresh indicator widget
  Widget _buildRefreshIndicator(IndicatorController indicatorController) {
    final value = indicatorController.value.clamp(0.0, 1.5);
    return Container(
      height: 60 * value,
      alignment: Alignment.center,
      child: indicatorController.isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              CupertinoIcons.arrow_down,
              size: 24 * value,
              color: Colors.grey,
            ),
    );
  }

  /// Build bottom pull-up load more indicator widget
  Widget _buildLoadMorePullIndicator(IndicatorController indicatorController) {
    // Don't show if no more data
    if (!controller.hasMoreTransactions.value) {
      return const SizedBox.shrink();
    }

    final value = indicatorController.value.clamp(0.0, 1.5);
    return Container(
      height: 60 * value,
      alignment: Alignment.center,
      child: indicatorController.isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              CupertinoIcons.arrow_up,
              size: 24 * value,
              color: Colors.grey,
            ),
    );
  }

  /// Build load more indicator widget (static indicator in list)
  Widget _buildLoadMoreIndicator(BuildContext context) {
    return Obx(() {
      // Loading more state - handled by pull indicator now
      if (controller.isLoadingMore.value) {
        return const SizedBox.shrink();
      }

      // No more data state
      if (!controller.hasMoreTransactions.value) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'No more data',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                fontSize: 14,
              ),
            ),
          ),
        );
      }

      // Has more data - show hint text
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            'Pull up to load more',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
              fontSize: 12,
            ),
          ),
        ),
      );
    });
  }

  /// Individual transaction tile
  Widget _buildTransactionTile(
    BuildContext context,
    WalletTransactionBase transaction,
  ) {
    final isIncoming = transaction.isIncoming;
    final amountText =
        '${isIncoming ? '+' : '-'} ${transaction.amountSats.abs()}';

    return ListTile(
      key: Key(transaction.id + transaction.timestamp.toString()),
      dense: true,
      leading: Icon(
        isIncoming
            ? CupertinoIcons.arrow_down_left
            : CupertinoIcons.arrow_up_right,
        color: isIncoming ? Colors.green : Colors.red,
      ),
      title: Text(
        amountText,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: Row(
        children: [
          // Protocol badge
          _buildTransactionProtocolBadge(transaction.protocol),
          // // Transaction type badge for Cashu (Ecash/Lightning)
          // if (transaction is CashuWalletTransaction)
          //   _buildTransactionTypeBadge(transaction),
          // const SizedBox(width: 4),
          // Status and time
          Expanded(
            child: textSmallGray(
              context,
              '${_getStatusText(transaction.status)} - ${formatTime(transaction.timestamp.millisecondsSinceEpoch)}',
            ),
          ),
        ],
      ),
      trailing: _buildTransactionStatusIcon(transaction.status),
      onTap: () => _onTransactionTap(transaction),
    );
  }

  /// Protocol badge for transaction
  Widget _buildTransactionProtocolBadge(WalletProtocol protocol) {
    final (label, color) = switch (protocol) {
      WalletProtocol.cashu => ('Cashu', KeychatGlobal.secondaryColor),
      WalletProtocol.nwc => ('NWC', KeychatGlobal.bitcoinColor),
    };

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Transaction type badge for Cashu (Ecash/Lightning)
  Widget _buildTransactionTypeBadge(CashuWalletTransaction transaction) {
    final isLightning = transaction.rawData.kind == TransactionKind.ln;
    final (label, color) = isLightning
        ? ('Lightning', KeychatGlobal.bitcoinColor)
        : ('Ecash', KeychatGlobal.secondaryColor);

    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Transaction status icon
  Widget _buildTransactionStatusIcon(WalletTransactionStatus status) {
    return switch (status) {
      WalletTransactionStatus.pending => const Icon(
          CupertinoIcons.clock,
          color: Colors.orange,
          size: 18,
        ),
      WalletTransactionStatus.success => const Icon(
          CupertinoIcons.checkmark_circle,
          color: Colors.green,
          size: 18,
        ),
      WalletTransactionStatus.failed => const Icon(
          CupertinoIcons.xmark_circle,
          color: Colors.red,
          size: 18,
        ),
      WalletTransactionStatus.expired => const Icon(
          CupertinoIcons.clock,
          color: Colors.grey,
          size: 18,
        ),
    };
  }

  String _getStatusText(WalletTransactionStatus status) {
    return switch (status) {
      WalletTransactionStatus.pending => 'Pending',
      WalletTransactionStatus.success => 'Success',
      WalletTransactionStatus.failed => 'Failed',
      WalletTransactionStatus.expired => 'Expired',
    };
  }

  /// Get gradient colors for wallet card
  List<Color> _getWalletGradientColors(WalletBase wallet) {
    final hash = wallet.id.hashCode;
    return [
      if (wallet.protocol == WalletProtocol.cashu)
        KeychatGlobal.secondaryColor.withAlpha(100)
      else
        KeychatGlobal.bitcoinColor.withAlpha(100),
      Color((hash & 0xFFFFFF) | 0x40000000),
    ];
  }

  /// Handle wallet card tap - navigate to wallet details
  Future<void> _onWalletCardTap(WalletBase wallet) async {
    bool? deleted;
    if (wallet is CashuWallet) {
      deleted = await Get.to<bool>(
        () => MintServerPage(wallet.rawData),
        id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
      );
    } else if (wallet is NwcWallet) {
      deleted = await Get.to<bool>(
        () => NwcSettingPage(connection: wallet.rawData),
        id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
      );
    }
    if (deleted ?? false) {
      await controller.selectWallet(0);
      await controller.refreshAll();
    }
  }

  /// Handle transaction tap - navigate to transaction details
  void _onTransactionTap(WalletTransactionBase transaction) {
    if (transaction is CashuWalletTransaction) {
      final tx = transaction.rawData;
      final isLightning = tx.kind == TransactionKind.ln;

      if (isLightning) {
        // Use unified page for Cashu Lightning transactions
        Get.to<void>(
          () => UnifiedTransactionPage(
            cashuTransaction: tx,
            walletId: tx.mintUrl,
          ),
          id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
        );
      } else {
        // Use Cashu-specific page for Ecash transactions
        Get.to<void>(
          () => CashuTransactionPage(transaction: tx),
          id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
        );
      }
    } else if (transaction is NwcWalletTransaction) {
      // Use unified page for NWC Lightning transactions
      final wallet = controller.selectedWallet;
      Get.to<void>(
        () => UnifiedTransactionPage(
          nwcTransaction: transaction.rawData,
          walletId: wallet is NwcWallet ? wallet.id : null,
        ),
        id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
      );
    }
  }

  /// Show dialog to add a new wallet
  Future<void> _showAddWalletDialog(BuildContext context) async {
    final result = await Get.bottomSheet<String>(
      CupertinoActionSheet(
        title: const Text('Add Wallet'),
        message: const Text(
          'Paste a Cashu mint URL or NWC connection string',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              final scanned = await QrScanService.instance.handleQRScan();
              Get.back(result: scanned);
            },
            child: const Text('Scan QR Code'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null && data!.text!.isNotEmpty) {
                Get.back(result: data.text);
                return;
              }
              await EasyLoading.showError('Clipboard is empty');
              Get.back();
            },
            child: const Text('Paste from Clipboard'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Get.back<void>(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _processWalletInput(result);
    }
  }

  /// Process wallet input and add appropriate wallet type
  Future<void> _processWalletInput(String input) async {
    final trimmedInput = input.trim();

    // Detect wallet type
    final walletType = controller.detectWalletType(trimmedInput);

    if (walletType == null) {
      await EasyLoading.showError(
        'Invalid input. Please enter a valid Cashu mint URL or NWC connection string.',
      );
      return;
    }

    await controller.addWallet(trimmedInput);
  }
}
