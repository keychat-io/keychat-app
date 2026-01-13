import 'package:flutter/cupertino.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/components/SelectMintAndNwc.dart';
import 'package:keychat_ecash/wallet_selection_storage.dart';
import 'package:keychat_nwc/nwc/nwc_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

class CreateInvoiceController extends GetxController {
  CreateInvoiceController({this.defaultAmount, this.defaultDescription});
  final int? defaultAmount;
  final String? defaultDescription;

  EcashController ecashController = Get.find<EcashController>();
  late TextEditingController textController;
  late TextEditingController descController;

  @override
  void onInit() {
    textController = TextEditingController();
    descController = TextEditingController();
    if (defaultAmount != null) {
      textController.text = defaultAmount.toString();
    }
    if (defaultDescription != null) {
      descController.text = defaultDescription!;
    }
    super.onInit();
  }

  @override
  void onClose() {
    textController.dispose();
    descController.dispose();
    super.onClose();
  }

  Future<void> handleCreateInvoice() async {
    if (GetPlatform.isMobile) {
      HapticFeedback.lightImpact();
    }
    final amountString = textController.text.trim();
    if (amountString.isEmpty) {
      EasyLoading.showToast('Please input amount');
      return;
    }
    final amount = int.parse(amountString);
    if (amount == 0) {
      EasyLoading.showToast('Amount should > 0');
      return;
    }

    if (amount > 1000) {
      final result = await Get.dialog<bool>(
        CupertinoAlertDialog(
          title: const Text('Warning'),
          content: const Text(
            '''
Amounts over 1000 sats carry higher risk. 
If payment fails, please contact the mint server.''',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Get.back(result: true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (result != true) {
        return;
      }
    }

    try {
      EasyLoading.show(status: 'Generating...');
      final description = descController.text.trim();
      // Handle NWC wallet
      if (ecashController.selectedWallet.value.type == WalletType.nwc) {
        final nwcController = Utils.getOrPutGetxController(
          create: NwcController.new,
        );
        final active = nwcController.activeConnections.firstWhereOrNull(
          (c) => c.info.uri == ecashController.selectedWallet.value.id,
        );

        if (active == null) {
          EasyLoading.showError('NWC connection not found');
          return;
        }

        final response = await nwcController.ndk.nwc.makeInvoice(
          active.connection,
          amountSats: amount,
          description: description,
        );

        await EasyLoading.showSuccess('Invoice created');
        Get.back(result: response); // MakeInvoiceResponse
        return;
      }

      // Handle Cashu mint: Transaction
      final tr = await rust_cashu.requestMint(
        amount: BigInt.from(amount),
        activeMint: ecashController.selectedWallet.value.id,
      );
      Get.find<EcashController>().getRecentTransactions();
      await EasyLoading.showToast('Create Successfully');
      textController.clear();
      Get.back(result: tr);
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
      logger.e(msg, error: e, stackTrace: s);
      await EasyLoading.showToast(msg);
    }
  }
}
