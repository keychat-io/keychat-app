import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class LightningUtils {
  // Avoid self instance
  LightningUtils._();
  static LightningUtils? _instance;
  static LightningUtils get instance => _instance ??= LightningUtils._();
  bool run = false;

  Future<void> checkPendings(List<Transaction> pendings) async {
    if (pendings.isEmpty) return;
    var length = pendings.length;
    while (true) {
      if (run) return;
      run = true;
      await rust_cashu.checkPending();
      final list = await rust_cashu.getLnPendingTransactions();
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
  Future<void> startCheckPending(
    Transaction tx,
    int expiryTs,
    Function(Transaction ln) callback,
  ) async {
    if (tx.status != TransactionStatus.pending) {
      callback(tx);
      return;
    }

    pendingTaskMap[tx.id] = true;

    while (pendingTaskMap[tx.id] != null && pendingTaskMap[tx.id] == true) {
      final ln = await rust_cashu.checkTransaction(id: tx.id);
      final now = DateTime.now().millisecondsSinceEpoch;

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
