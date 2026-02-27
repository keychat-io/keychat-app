import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/unified_wallet/unified_wallet_controller.dart';

/// Page that displays 1sat (stamp) transactions for the selected Cashu wallet.
///
/// Uses [UnifiedWalletController] to load paginated 1sat transactions.
/// Supports pull-down to refresh and pull-up to load more via
/// [CustomRefreshIndicator] with [IndicatorTrigger.bothEdges].
class OneSatTransactionsPage extends StatelessWidget {
  const OneSatTransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<UnifiedWalletController>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('1sat Transactions'),
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
        centerTitle: true,
      ),
      body: _OneSatTransactionsList(controller: controller),
    );
  }
}

/// Stateful widget that manages the refresh indicator controller lifecycle.
class _OneSatTransactionsList extends StatefulWidget {
  const _OneSatTransactionsList({required this.controller});

  final UnifiedWalletController controller;

  @override
  State<_OneSatTransactionsList> createState() =>
      _OneSatTransactionsListState();
}

class _OneSatTransactionsListState extends State<_OneSatTransactionsList> {
  final _indicatorController = IndicatorController();

  UnifiedWalletController get controller => widget.controller;

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Loading state
      if (controller.isOneSatTransactionsLoading.value &&
          controller.oneSatTransactions.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      // Empty state
      if (controller.oneSatTransactions.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.doc_text,
                size: 64,
                color: Colors.grey.withAlpha(120),
              ),
              const SizedBox(height: 16),
              Text(
                'No 1sat Transactions',
                style: TextStyle(
                  color: Colors.grey.withAlpha(160),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }

      // Transaction list with pull-to-refresh and pull-up-to-load-more
      return CustomRefreshIndicator(
        controller: _indicatorController,
        onRefresh: () async {
          if (_indicatorController.side == IndicatorSide.top) {
            // Pull down - refresh
            await controller.loadOneSatTransactions(forceRefresh: true);
          } else if (_indicatorController.side == IndicatorSide.bottom) {
            // Pull up - load more
            await controller.loadMoreOneSatTransactions();
          }
        },
        trigger: IndicatorTrigger.bothEdges,
        builder: (context, child, indicatorController) {
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
                  child: _buildLoadMoreIndicator(indicatorController),
                ),
            ],
          );
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: controller.oneSatTransactions.length + 1,
          itemBuilder: (context, index) {
            if (index == controller.oneSatTransactions.length) {
              return _buildFooter();
            }
            return _buildTransactionTile(
              context,
              controller.oneSatTransactions[index],
            );
          },
        ),
      );
    });
  }

  /// Build top pull-down refresh indicator
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

  /// Build bottom pull-up load more indicator
  Widget _buildLoadMoreIndicator(IndicatorController indicatorController) {
    if (!controller.hasMoreOneSatTransactions.value) {
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

  /// Build footer with load status text
  Widget _buildFooter() {
    return Obx(() {
      if (controller.isLoadingMoreOneSat.value) {
        return const SizedBox.shrink();
      }

      if (!controller.hasMoreOneSatTransactions.value) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'No more transactions',
              style: TextStyle(
                color: Colors.grey.withAlpha(160),
                fontSize: 12,
              ),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            'Pull up to load more',
            style: TextStyle(
              color: Colors.grey.withAlpha(160),
              fontSize: 12,
            ),
          ),
        ),
      );
    });
  }

  /// Build a single transaction tile (matching main wallet page style)
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
          Expanded(
            child: textSmallGray(
              context,
              '${_getStatusText(transaction.status)} - ${formatTime(transaction.timestamp.millisecondsSinceEpoch)}',
            ),
          ),
        ],
      ),
      trailing: _buildStatusIcon(transaction.status),
      onTap: () => transaction.navigateToTransactionDetail(
        walletId: controller.selectedWallet.id,
      ),
    );
  }

  String _getStatusText(WalletTransactionStatus status) {
    return switch (status) {
      WalletTransactionStatus.pending => 'Pending',
      WalletTransactionStatus.success => 'Success',
      WalletTransactionStatus.failed => 'Failed',
      WalletTransactionStatus.expired => 'Expired',
    };
  }

  /// Transaction status icon
  Widget _buildStatusIcon(WalletTransactionStatus status) {
    return switch (status) {
      WalletTransactionStatus.pending => const Icon(
          CupertinoIcons.clock,
          color: Colors.orange,
          size: 20,
        ),
      WalletTransactionStatus.success => const Icon(
          CupertinoIcons.checkmark_circle,
          color: Colors.green,
          size: 20,
        ),
      WalletTransactionStatus.failed => const Icon(
          CupertinoIcons.xmark_circle,
          color: Colors.red,
          size: 20,
        ),
      WalletTransactionStatus.expired => const Icon(
          CupertinoIcons.clock_fill,
          color: Colors.grey,
          size: 20,
        ),
    };
  }
}
