import 'package:app/global.dart';
import 'package:app/utils.dart';
import 'package:flutter/services.dart';
import 'package:keychat_ecash/Bills/lightning_bill_controller.dart';
import 'package:keychat_ecash/Bills/lightning_transaction.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class CreateInvoiceController extends GetxController {
  EcashController cashuController = Get.find<EcashController>();
  LightningBillController lightningBillController =
      Get.find<LightningBillController>();
  late TextEditingController textController;
  RxString selectedMint = ''.obs;
  @override
  void onInit() {
    selectedMint.value = cashuController.latestMintUrl.value;
    textController = TextEditingController();
    super.onInit();
  }

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }

  void handleReceiveInvoice() async {
    if (GetPlatform.isMobile) {
      HapticFeedback.lightImpact();
    }
    String amountString = textController.text.trim();
    if (amountString.isEmpty) {
      EasyLoading.showToast('Please input amount');
      return;
    }
    int amount = int.parse(amountString);
    if (amount == 0) {
      EasyLoading.showToast('Amount should > 0');
      return;
    }

    try {
      EasyLoading.show(status: 'Generating...');
      Transaction tr = await rust_cashu.requestMint(
          amount: BigInt.from(amount), activeMint: selectedMint.value);
      LNTransaction ln = tr.field0 as LNTransaction;
      EasyLoading.dismiss();
      EasyLoading.showToast('Create Successfully');
      textController.clear();
      if (Get.isBottomSheetOpen ?? false) {
        Get.back();
      }
      await Get.to(() => LightningTransactionPage(transaction: ln),
          id: GetPlatform.isDesktop ? GetXNestKey.ecash : null);
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      EasyLoading.showToast('Exception: $msg');
      logger.e(msg, error: e, stackTrace: s);
    }
    var ecashController = Get.find<EcashController>();
    await ecashController.refreshController.requestRefresh();
    await ecashController.requestPageRefresh();
  }
}
