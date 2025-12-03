import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/utils.dart' show formatTime;
import 'package:keychat_ecash/Bills/cashu_transaction.dart';
import 'package:keychat_ecash/Bills/lightning_transaction.dart';
import 'package:keychat_ecash/Bills/transactions_controller.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late final TransactionsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(TransactionsController());
  }

  @override
  void dispose() {
    Get.delete<TransactionsController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Transactions'),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          width: double.infinity,
          padding:
              GetPlatform.isDesktop ? const EdgeInsets.all(8) : EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Obx(
                  () => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFilterButton(
                        context,
                        'All',
                        TransactionFilter.all,
                      ),
                      const SizedBox(width: 12),
                      _buildFilterButton(
                        context,
                        'Cashu',
                        TransactionFilter.cashu,
                      ),
                      const SizedBox(width: 12),
                      _buildFilterButton(
                        context,
                        'Lightning',
                        TransactionFilter.lightning,
                      ),
                      const SizedBox(width: 12),
                      _buildFilterButton(
                        context,
                        'Failed',
                        TransactionFilter.failed,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Obx(
                  () => !controller.status.value &&
                          controller.transactions.isEmpty
                      ? const Center(
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: SpinKitWave(
                              color: Color.fromARGB(255, 141, 123, 243),
                              size: 40,
                            ),
                          ),
                        )
                      : Obx(
                          () => CustomMaterialIndicator(
                            onRefresh: () async {
                              var offset = controller.transactions.length;
                              if (controller.indicatorController.edge ==
                                  IndicatorEdge.leading) {
                                offset = 0;
                              }
                              await controller.getTransactions(offset: offset);
                            },
                            displacement: 20,
                            backgroundColor: Colors.white,
                            trigger: IndicatorTrigger.bothEdges,
                            triggerMode: IndicatorTriggerMode.anywhere,
                            controller: controller.indicatorController,
                            child: ListView.separated(
                              separatorBuilder: (
                                BuildContext context2,
                                int index,
                              ) =>
                                  Divider(
                                color: Theme.of(context).dividerTheme.color,
                                thickness: 0.2,
                                height: 1,
                              ),
                              itemCount: controller.transactions.length,
                              itemBuilder: (BuildContext context, int index) {
                                final transaction =
                                    controller.transactions[index];
                                return _buildTransactionItem(
                                  context,
                                  transaction,
                                );
                              },
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context,
    String label,
    TransactionFilter filter,
  ) {
    final isSelected = controller.currentFilter.value == filter;
    return ElevatedButton(
      onPressed: () => controller.changeFilter(filter),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).primaryColor
            : Theme.of(context).colorScheme.surface,
        foregroundColor: isSelected
            ? Colors.white
            : Theme.of(context).textTheme.bodyMedium?.color,
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction) {
    final isLightning = transaction.kind == TransactionKind.ln;

    return ListTile(
      dense: true,
      onTap: () async {
        final originalStatus = transaction.status;

        if (isLightning) {
          await Get.to(
            () => LightningTransactionPage(transaction: transaction),
          );
        } else {
          await Get.to(() => CashuTransactionPage(transaction: transaction));
        }

        // Check if status changed and update only this transaction
        final updatedTx = await controller.getTransactionById(transaction.id);
        if (updatedTx != null && updatedTx.status != originalStatus) {
          controller.updateTransactionInList(updatedTx);
        }
      },
      leading: EcashUtils.getTransactionIcon(transaction.io),
      title: Text(
        '${EcashUtils.getSymbolFromDirection(transaction.io)} ${transaction.amount}',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: Row(
        children: [
          if (isLightning)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(50),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'Lightning',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: textSmallGray(
              context,
              'Fee: ${transaction.fee} ${transaction.unit} - ${formatTime(transaction.timestamp.toInt() * 1000)}',
            ),
          ),
        ],
      ),
      trailing: isLightning
          ? EcashUtils.getLNIcon(transaction.status)
          : EcashUtils.getStatusIcon(transaction.status),
    );
  }
}
