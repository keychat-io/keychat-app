import 'package:app/app.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

class LightningBillController extends GetxController {
  RxList<Transaction> transactions = <Transaction>[].obs;
  RxBool status = false.obs;
  bool run = true;
  late IndicatorController indicatorController;

  @override
  void onInit() {
    super.onInit();
    indicatorController = IndicatorController();
    Future.delayed(Duration(seconds: 1)).then((_) {
      getTransactions().then((list) {
        status.value = true;
        rust_cashu.getLnPendingTransactions().then(checkPendings);
      });
    });
  }

  @override
  onClose() {
    run = false;
    indicatorController.dispose();
    super.onClose();
  }

  Future<List<Transaction>> getTransactions(
      {int offset = 0, int limit = 15}) async {
    List<Transaction> list = await rust_cashu.getLnTransactionsWithOffset(
        offset: BigInt.from(offset), limit: BigInt.from(limit));
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    List<Transaction> res = offset == 0 ? [] : transactions.toList();

    res.addAll(list);
    transactions.value = res;
    transactions.refresh();
    return res;
  }

  Future<void> checkPendings(List<Transaction> pendings) async {
    if (pendings.isEmpty) return;
    int length = pendings.length;
    while (true) {
      if (run) return;
      run = true;
      await rust_cashu.checkPending();
      var list = await rust_cashu.getLnPendingTransactions();
      if (list.isEmpty) {
        run = false;
        Get.find<EcashController>().getBalance();
        logger.d('tx status changed, update balance');
        return;
      }
      logger.d('Timer, pendings: ${list.length}');
      if (list.length != length) {
        length = list.length;
        logger.d('tx status changed, update balance');
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Map pendingTaskMap = {};
  void startCheckPending(
      Transaction tx, int expiryTs, Function(Transaction ln) callback) async {
    if (tx.status != TransactionStatus.pending) {
      callback(tx);
      return;
    }

    pendingTaskMap[tx.id] = true;

    while (pendingTaskMap[tx.id] != null && pendingTaskMap[tx.id] == true) {
      Transaction ln = await rust_cashu.checkTransaction(id: tx.id);
      int now = DateTime.now().millisecondsSinceEpoch;

      if (ln.status == TransactionStatus.success ||
          ln.status == TransactionStatus.failed ||
          (now > expiryTs && expiryTs > 0)) {
        callback(ln);
        Get.find<EcashController>().requestPageRefresh();
        pendingTaskMap.remove(tx.id);
        return;
      }
      logger.d('Checking status: ${tx.id}');
      await Future.delayed(const Duration(seconds: 2));
    }

    logger.d('Check stopped for transaction: ${tx.id}');
  }

  void stopCheckPending(Transaction tx) {
    if (pendingTaskMap.containsKey(tx.id)) {
      pendingTaskMap[tx.id] = false;
      logger.d('Stopping check for lightning transaction: ${tx.id}');
    }
  }
}
