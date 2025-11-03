import 'package:app/app.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

enum TransactionFilter { all, cashu, lightning }

class TransactionsController extends GetxController {
  RxList<Transaction> transactions = <Transaction>[].obs;
  RxBool status = false.obs;
  Rx<TransactionFilter> currentFilter = TransactionFilter.all.obs;
  late IndicatorController indicatorController;
  final Map<String, bool> _activeChecks = {};

  @override
  void onInit() {
    super.onInit();
    indicatorController = IndicatorController();
    Future.delayed(const Duration(seconds: 1)).then((_) {
      getTransactions().then((list) {
        status.value = true;
        rust_cashu.checkPending().then((_) {
          Get.find<EcashController>().getBalance();
        });
      });
    });
  }

  @override
  void onClose() {
    indicatorController.dispose();
    super.onClose();
  }

  void changeFilter(TransactionFilter filter) {
    currentFilter.value = filter;
    status.value = false;
    transactions.clear();
    getTransactions().then((_) {
      status.value = true;
    });
  }

  Future<List<Transaction>> getTransactions({
    int offset = 0,
    int limit = 30,
  }) async {
    List<Transaction> list;

    switch (currentFilter.value) {
      case TransactionFilter.all:
        list = await rust_cashu.getTransactionsWithOffset(
          offset: BigInt.from(offset),
          limit: BigInt.from(limit),
        );
      case TransactionFilter.cashu:
        list = await rust_cashu.getCashuTransactionsWithOffset(
          offset: BigInt.from(offset),
          limit: BigInt.from(limit),
        );
      case TransactionFilter.lightning:
        list = await rust_cashu.getLnTransactionsWithOffset(
          offset: BigInt.from(offset),
          limit: BigInt.from(limit),
        );
    }

    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final res = offset == 0 ? <Transaction>[] : transactions.toList()
      ..addAll(list);
    transactions.value = res;
    transactions.refresh();
    return res;
  }

  Future<Transaction?> getTransactionById(String id) async {
    try {
      return await rust_cashu.checkTransaction(id: id);
    } catch (e) {
      logger.e('Failed to get transaction by id', error: e);
      return null;
    }
  }

  void updateTransactionInList(Transaction updatedTransaction) {
    final index =
        transactions.indexWhere((tx) => tx.id == updatedTransaction.id);
    if (index != -1) {
      transactions[index] = updatedTransaction;
      transactions.refresh();
    }
  }

  Future<void> startCheckPending(
    Transaction tx,
    void Function(Transaction) callback,
  ) async {
    if (tx.status != TransactionStatus.pending) {
      callback(tx);
      return;
    }

    _activeChecks[tx.id] = true;

    while (_activeChecks[tx.id] != null && (_activeChecks[tx.id] ?? false)) {
      final updatedTx = await rust_cashu.checkTransaction(id: tx.id);

      if (updatedTx.status == TransactionStatus.success ||
          updatedTx.status == TransactionStatus.failed) {
        callback(updatedTx);
        Get.find<EcashController>().requestPageRefresh();
        _activeChecks.remove(tx.id);
        return;
      }
      logger.d('Checking status: ${tx.id}');
      await Future.delayed(const Duration(seconds: 2));
    }

    logger.d('Check stopped for transaction: ${tx.id}');
  }

  void stopCheckPending(Transaction tx) {
    if (_activeChecks.containsKey(tx.id)) {
      _activeChecks[tx.id] = false;
      logger.d('Stopping check for transaction: ${tx.id}');
    }
  }
}
