import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/page/theme.dart';
import 'package:keychat/utils.dart' show BottomSheetContainer;
import 'package:keychat_ecash/CreateInvoice/CreateInvoice_controller.dart';
import 'package:keychat_ecash/components/SelectMintAndNwc.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';

// return: BaseWalletTransaction
class CreateInvoicePage extends StatelessWidget {
  CreateInvoicePage({this.amount, this.description, super.key});
  final int? amount;
  final String? description;
  final RxBool isLoading = false.obs;

  @override
  Widget build(BuildContext context) {
    final ecashController = Get.find<EcashController>();
    final controller = Get.put(CreateInvoiceController(defaultAmount: amount));

    return BottomSheetContainer(
      title: 'Make Invoice',
      children: [
        const SelectMintAndNwc(),
        const SizedBox(height: 8),
        Expanded(
          child: Form(
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(fontSize: 18),
                  controller: controller.textController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Input Amount',
                    hintText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  style: const TextStyle(fontSize: 18),
                  controller: controller.descController,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => (ecashController.selectedWallet.value.protocol ==
                          WalletProtocol.cashu &&
                      ecashController.supportMint(
                        ecashController.selectedWallet.value.id,
                      )) ||
                  ecashController.selectedWallet.value.protocol ==
                      WalletProtocol.nwc
              ? SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: Obx(
                    () => FilledButton(
                      onPressed: isLoading.value
                          ? null
                          : () async {
                              if (isLoading.value) return;
                              try {
                                isLoading.value = true;
                                await controller.handleCreateInvoice();
                              } finally {
                                isLoading.value = false;
                              }
                            },
                      child: isLoading.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Make Invoice'),
                    ),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: null,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.disabled)) {
                            return Colors.grey;
                          }
                          return MaterialTheme.lightScheme().primary;
                        },
                      ),
                    ),
                    child: const Text('Disable By Mint Server'),
                  ),
                ),
        ),
      ],
    );
  }
}
