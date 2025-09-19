import 'dart:async';

import 'package:app/utils.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class EcashBillController extends GetxController {
  RxList<Transaction> transactions = <Transaction>[].obs;
  RxBool status = false.obs;
  late IndicatorController indicatorController;
  final Map<String, bool> _activeChecks = {};

  @override
  void onInit() {
    indicatorController = IndicatorController();
    initPageData();
    super.onInit();
  }

  @override
  void onClose() {
    indicatorController.dispose();
    super.onClose();
  }

  void initPageData() {
    Future.delayed(const Duration(seconds: 1)).then((_) {
      rust_cashu.checkPending().then(
        (value) async {
          await Utils.getGetxController<EcashController>()?.getBalance();
          status.value = true;
          getTransactions();
        },
      );
    });
  }

  Future<void> getTransactions({int offset = 0, int limit = 30}) async {
    final list = await rust_cashu.getCashuTransactionsWithOffset(
        offset: BigInt.from(offset), limit: BigInt.from(limit));
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final res = offset == 0 ? <Transaction>[] : transactions.toList()
      ..addAll(list);
    transactions.value = res;
    transactions.refresh();
  }

  Future<void> startCheckPending(
      Transaction tx, void Function(Transaction ct) callback) async {
    if (tx.status != TransactionStatus.pending) {
      callback(tx);
      return;
    }

    _activeChecks[tx.id] = true;

    while (_activeChecks[tx.id] != null && (_activeChecks[tx.id] ?? false)) {
      final ln = await rust_cashu.checkTransaction(id: tx.id);
      if (ln.status == TransactionStatus.success ||
          ln.status == TransactionStatus.failed) {
        callback(ln);
        unawaited(Get.find<EcashController>().requestPageRefresh());
        _activeChecks.remove(tx.id);
        return;
      }
      logger.d('Checking status: ${tx.id}');
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    logger.d('Check stopped for transaction: ${tx.id}');
  }

  void stopCheckPending(Transaction tx) {
    if (_activeChecks.containsKey(tx.id)) {
      _activeChecks.remove(tx.id);
      logger.d('Stopping check for transaction: ${tx.id}');
    }
  }
}
