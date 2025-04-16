// ignore_for_file: depend_on_referenced_packages

import 'package:app/page/theme.dart';
import 'package:keychat_ecash/components/SelectMint.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import './CreateInvoice_controller.dart';

class CreateInvoicePage extends StatelessWidget {
  const CreateInvoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    EcashController cashuController = Get.find<EcashController>();

    CreateInvoiceController controller = Get.put(CreateInvoiceController());

    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: Container(),
          centerTitle: true,
          title: Text(
            'Receive From Lightning Network',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        body: Container(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            decoration:
                BoxDecoration(color: Theme.of(context).colorScheme.surface),
            child: Column(children: [
              SelectMint(controller.selectedMint.value, (mint) {
                controller.selectedMint.value = mint;
              }),
              const SizedBox(height: 10),
              Form(
                child: Expanded(
                    child: Column(children: [
                  TextField(
                      style: const TextStyle(fontSize: 20),
                      controller: controller.textController,
                      keyboardType: TextInputType.number,
                      // textInputAction: TextInputAction.done,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Input Amount',
                        hintText: 'Amount',
                        border: OutlineInputBorder(),
                      )),
                ])),
              ),
              Obx(() => cashuController
                      .supportMint(controller.selectedMint.value)
                  ? FilledButton(
                      style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all(
                              const Size(double.infinity, 44))),
                      onPressed: controller.handleReceiveInvoice,
                      child: const Text('Create Invoice'))
                  : FilledButton(
                      onPressed: null,
                      style: ButtonStyle(
                        minimumSize: WidgetStateProperty.all(
                            const Size(double.infinity, 44)),
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.disabled)) {
                              return Colors.grey;
                            }
                            return MaterialTheme.lightScheme().primary;
                          },
                        ),
                      ),
                      child: const Text('Disable By Mint Server')))
            ])));
  }
}
