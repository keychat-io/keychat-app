// ignore_for_file: depend_on_referenced_packages
import 'package:app/page/theme.dart';
import 'package:app/service/qrscan.service.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:keychat_ecash/components/SelectMint.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import './PayInvoice_controller.dart';

class PayInvoicePage extends StatefulWidget {
  final String? invoce;
  const PayInvoicePage({super.key, this.invoce});

  @override
  _PayInvoicePageState createState() => _PayInvoicePageState();
}

class _PayInvoicePageState extends State<PayInvoicePage> {
  late EcashController cashuController;
  late PayInvoiceController controller;
  @override
  void initState() {
    controller = Get.put(PayInvoiceController(widget.invoce));
    cashuController = Get.find<EcashController>();
    cashuController.getBalance();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: Container(),
          centerTitle: true,
          title: Text(
            'Send to LightingNetwork',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        body: SafeArea(
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
                child: Column(children: [
                  Form(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Expanded(
                        child: Column(
                      children: [
                        Obx(() =>
                            SelectMint(cashuController.latestMintUrl.value,
                                (String mint) {
                              cashuController.latestMintUrl.value = mint;
                              controller.selectedMint.value = mint;
                            })),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          child: TextField(
                            controller: controller.textController,
                            textInputAction: TextInputAction.done,
                            autofocus: true,
                            maxLines: 8,
                            style: const TextStyle(fontSize: 10),
                            decoration: InputDecoration(
                                labelText: 'Input Invoice',
                                hintText: 'Paste Lightning invoice',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.paste),
                                  onPressed: () async {
                                    final clipboardData =
                                        await Clipboard.getData('text/plain');
                                    if (clipboardData != null) {
                                      final pastedText = clipboardData.text;
                                      if (pastedText != null &&
                                          pastedText != '') {
                                        controller.textController.text =
                                            pastedText;
                                      }
                                    }
                                  },
                                )),
                          ),
                        ),
                        OutlinedButton.icon(
                            onPressed: () async {
                              String? result =
                                  await QrScanService.instance.handleQRScan();
                              if (result != null) {
                                controller.textController.text = result;
                              }
                            },
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan')),
                      ],
                    )),
                  ),
                  Obx(() => cashuController
                          .supportMint(controller.selectedMint.value)
                      ? FilledButton(
                          style: ButtonStyle(
                              minimumSize: WidgetStateProperty.all(
                                  const Size(double.infinity, 44))),
                          onPressed: () {
                            controller.confirm(controller.selectedMint.value);
                          },
                          child: const Text('Pay Invoice'),
                        )
                      : FilledButton(
                          onPressed: null,
                          style: ButtonStyle(
                            minimumSize: WidgetStateProperty.all(
                                const Size(double.infinity, 44)),
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
                          child: const Text(
                            'Disabled By Mint Server',
                          ))),
                ]))));
  }
}
