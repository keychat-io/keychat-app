import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rustCashu;

import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class EcashBillController extends GetxController {
  RxList<CashuTransaction> transactions = <CashuTransaction>[].obs;
  RxBool status = false.obs;
  late RefreshController refreshController;

  @override
  void onInit() async {
    refreshController = RefreshController();
    super.onInit();
    getTransactions().then((e) {
      status.toggle();
      rustCashu.checkPending().then(
            (value) => getTransactions(),
          );
    });
  }

  @override
  onClose() {
    refreshController.dispose();
    super.onClose();
  }

  Future getTransactions({
    int offset = 0,
    int limit = 15,
  }) async {
    List<CashuTransaction> list =
        await rustCashu.getCashuTransactionsWithOffset(
            offset: BigInt.from(offset), limit: BigInt.from(limit));
    list.sort((a, b) => b.time.compareTo(a.time));

    List<CashuTransaction> res = offset == 0 ? [] : transactions.toList();
    res.addAll(list);
    transactions.value = res;
    transactions.refresh();
  }
}
