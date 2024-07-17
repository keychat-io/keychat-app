import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rustCashu;

class LightningBillController extends GetxController {
  RxList<LNTransaction> transactions = <LNTransaction>[].obs;
  RxBool status = false.obs;
  late RefreshController refreshController;

  @override
  void onInit() async {
    super.onInit();
    refreshController = RefreshController();
    getTransactions().then((l) => status.toggle());
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
    List<LNTransaction> list = await rustCashu.getLnTransactionsWithOffset(
        offset: BigInt.from(offset), limit: BigInt.from(limit));
    list.sort((a, b) => b.time.compareTo(a.time));

    List<LNTransaction> res = offset == 0 ? [] : transactions.toList();

    res.addAll(list);
    transactions.value = res;
    transactions.refresh();
  }
}
