import 'package:app/utils.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

class EcashBillController extends GetxController {
  RxList<CashuTransaction> transactions = <CashuTransaction>[].obs;
  RxBool status = false.obs;
  late RefreshController refreshController;

  final Map<String, bool> _activeChecks = {};

  @override
  void onInit() async {
    refreshController = RefreshController();
    initPageData();
    super.onInit();
  }

  @override
  onClose() {
    refreshController.dispose();
    super.onClose();
  }

  void initPageData() {
    Future.delayed(Duration(seconds: 1)).then((_) {
      rust_cashu.checkPending().then(
        (value) async {
          await Utils.getGetxController<EcashController>()?.getBalance();
          status.value = true;
          getTransactions();
        },
      );
    });
  }

  Future getTransactions({int offset = 0, int limit = 15}) async {
    List<CashuTransaction> list =
        await rust_cashu.getCashuTransactionsWithOffset(
            offset: BigInt.from(offset), limit: BigInt.from(limit));
    list.sort((a, b) => b.time.compareTo(a.time));

    List<CashuTransaction> res = offset == 0 ? [] : transactions.toList();
    res.addAll(list);
    transactions.value = res;
    transactions.refresh();
  }

  void startCheckPending(
      CashuTransaction tx, Function(CashuTransaction ct) callback) async {
    if (tx.status != TransactionStatus.pending) {
      callback(tx);
      return;
    }

    _activeChecks[tx.id] = true;

    while (_activeChecks[tx.id] != null && _activeChecks[tx.id] == true) {
      Transaction item = await rust_cashu.checkTransaction(id: tx.id);
      CashuTransaction ln = item.field0 as CashuTransaction;
      if (ln.status == TransactionStatus.success ||
          ln.status == TransactionStatus.failed) {
        callback(ln);
        Get.find<EcashController>().requestPageRefresh();
        _activeChecks.remove(tx.id);
        return;
      }
      logger.d('Checking status: ${tx.id}');
      await Future.delayed(const Duration(seconds: 1));
    }

    logger.d('Check stopped for transaction: ${tx.id}');
  }

  void stopCheckPending(CashuTransaction tx) {
    if (_activeChecks.containsKey(tx.id)) {
      _activeChecks.remove(tx.id);
      logger.d('Stopping check for transaction: ${tx.id}');
    }
  }
}
