import 'package:flutter/cupertino.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/unified_wallet/index.dart';

class CreateInvoiceController extends GetxController {
  CreateInvoiceController({this.defaultAmount, this.defaultDescription});
  final int? defaultAmount;
  final String? defaultDescription;

  late UnifiedWalletController unifiedWalletController;
  late TextEditingController textController;
  late TextEditingController descController;

  @override
  void onInit() {
    unifiedWalletController = Utils.getOrPutGetxController(
      create: UnifiedWalletController.new,
    );
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

  // Handle create invoice action
  // WalletTransaction
  Future<void> handleCreateInvoice() async {
    if (GetPlatform.isMobile) {
      await HapticFeedback.lightImpact();
    }
    final amountString = textController.text.trim();
    if (amountString.isEmpty) {
      await EasyLoading.showToast('Please input amount');
      return;
    }
    var amount = 0;
    try {
      amount = int.parse(amountString);
    } catch (e) {
      await EasyLoading.showToast('Input is invalid');
      return;
    }
    if (amount == 0) {
      await EasyLoading.showToast('Amount should > 0');
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
      final description = descController.text.trim();

      // Use unified wallet controller to create invoice
      final tx = await unifiedWalletController.createInvoiceWithTransaction(
        amount,
        description: description.isNotEmpty ? description : null,
      );

      if (tx != null) {
        textController.clear();
        Get.back(result: tx);
      }
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
      logger.e(msg, error: e, stackTrace: s);
      await EasyLoading.showToast(msg);
    }
  }
}
