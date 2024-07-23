import 'package:keychat_ecash/ecash_controller.dart';
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
    initPageData();
  }

  @override
  onClose() {
    refreshController.dispose();
    super.onClose();
  }

  initPageData() {
    rustCashu.checkPending().then(
      (value) async {
        await Get.find<EcashController>().getBalance();
        status.value = true;
        getTransactions();
      },
    );
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
