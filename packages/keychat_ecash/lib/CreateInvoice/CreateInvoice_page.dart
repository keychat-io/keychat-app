import 'package:app/page/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/CreateInvoice/CreateInvoice_controller.dart';
import 'package:keychat_ecash/components/SelectMint.dart';
import 'package:keychat_ecash/keychat_ecash.dart';

class CreateInvoicePage extends StatelessWidget {
  CreateInvoicePage({this.amount, this.showSelectMint = true, super.key});
  final int? amount;
  final bool showSelectMint;
  final RxBool isLoading = false.obs;

  @override
  Widget build(BuildContext context) {
    final cashuController = Get.find<EcashController>();
    final controller = Get.put(CreateInvoiceController(defaultAmount: amount));

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: Container(),
          centerTitle: true,
          title: Text(
            'Receive From Lightning Wallet',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        body: Container(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
          decoration:
              BoxDecoration(color: Theme.of(context).colorScheme.surface),
          child: Column(
            children: [
              if (showSelectMint)
                SelectMint(controller.selectedMint.value, (String mint) {
                  controller.selectedMint.value = mint;
                }),
              const SizedBox(height: 8),
              Expanded(
                child: Form(
                  child: Column(
                    children: [
                      TextField(
                        style: const TextStyle(fontSize: 18),
                        controller: controller.textController,
                        keyboardType: TextInputType.number,
                        // textInputAction: TextInputAction.done,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Input Amount',
                          hintText: 'Amount',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Obx(
                () => cashuController.supportMint(controller.selectedMint.value)
                    ? SizedBox(
                        width: GetPlatform.isDesktop ? 200 : double.infinity,
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
                                : const Text('Create Invoice'),
                          ),
                        ),
                      )
                    : SizedBox(
                        width: GetPlatform.isDesktop ? 200 : double.infinity,
                        height: 44,
                        child: FilledButton(
                          onPressed: null,
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color>(
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
          ),
        ),
      ),
    );
  }
}
