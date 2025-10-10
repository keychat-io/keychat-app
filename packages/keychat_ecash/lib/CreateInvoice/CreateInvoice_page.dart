import 'package:app/page/theme.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/CreateInvoice/CreateInvoice_controller.dart';
import 'package:keychat_ecash/components/SelectMint.dart';
import 'package:keychat_ecash/keychat_ecash.dart';

class CreateInvoicePage extends StatelessWidget {
  const CreateInvoicePage({this.amount, this.showSelectMint = true, super.key});
  final int? amount;
  final bool showSelectMint;

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
                    ? FilledButton(
                        style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all(
                            const Size(double.infinity, 44),
                          ),
                        ),
                        onPressed: () {
                          EasyThrottle.throttle('createInvoice',
                              const Duration(milliseconds: 2000), () async {
                            controller.handleCreateInvoice();
                          });
                        },
                        child: const Text('Create Invoice'),
                      )
                    : FilledButton(
                        onPressed: null,
                        style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all(
                            const Size(double.infinity, 44),
                          ),
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
            ],
          ),
        ),
      ),
    );
  }
}
