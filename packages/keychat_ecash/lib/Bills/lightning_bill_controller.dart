import 'package:app/app.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rustCashu;

class LightningBillController extends GetxController {
  RxList<LNTransaction> transactions = <LNTransaction>[].obs;
  RxBool status = false.obs;
  bool run = true;
  late RefreshController refreshController;
  late EcashController ecashController;

  @override
  void onInit() {
    super.onInit();
    ecashController = Get.find<EcashController>();
    refreshController = RefreshController();
    getTransactions().then((list) {
      status.value = true;
      getPendings(list).then(checkPendings);
    });
  }

  @override
  onClose() {
    run = false;
    refreshController.dispose();
    super.onClose();
  }

  Future<List<LNTransaction>> getTransactions({
    int offset = 0,
    int limit = 15,
  }) async {
    List<LNTransaction> list = await rustCashu.getLnTransactionsWithOffset(
        offset: BigInt.from(offset), limit: BigInt.from(limit));
    list.sort((a, b) => b.time.compareTo(a.time));

    List<LNTransaction> res = offset == 0 ? [] : transactions.toList();

    res.addAll(list);
    transactions.value = res;
    transactions.refresh();
    return res;
  }

  Future<List<LNTransaction>> getPendings([List<LNTransaction>? list]) async {
    list ??= await getTransactions();
    int now = DateTime.now().millisecondsSinceEpoch;
    List<LNTransaction> pendings = [];
    for (var element in list) {
      if (element.status == TransactionStatus.pending) {
        InvoiceInfo ii =
            await rustCashu.decodeInvoice(encodedInvoice: element.pr);
        if (ii.expiryTs.toInt() > now || ii.expiryTs.toInt() == 0) {
          pendings.add(element);
        }
      }
    }

    return pendings;
  }

  checkPendings(List<LNTransaction> pendings) async {
    if (pendings.isEmpty) return;
    int length = pendings.length;
    while (true) {
      if (!run) return;
      await rustCashu.checkPending();
      var list = await getPendings();
      if (list.isEmpty) {
        run = false;
        ecashController.getBalance();
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
  void startCheckPending(LNTransaction tx, int expiryTs,
      Function(LNTransaction ln) callback) async {
    if (tx.status != TransactionStatus.pending) {
      callback(tx);
      return;
    }
    while (true) {
      Transaction item = await rustCashu.checkTransaction(id: tx.hash);
      LNTransaction ln = item.field0 as LNTransaction;
      if (pendingTaskMap[ln.hash] == false) return;
      int now = DateTime.now().millisecondsSinceEpoch;

      if (ln.status == TransactionStatus.success ||
          ln.status == TransactionStatus.failed ||
          (now > expiryTs && expiryTs > 0)) {
        callback(ln);
        ecashController.requestPageRefresh();
        return;
      }
      logger.d('Checking status: ${tx.hash}');
      await Future.delayed(const Duration(seconds: 1));
    }
  }
}
