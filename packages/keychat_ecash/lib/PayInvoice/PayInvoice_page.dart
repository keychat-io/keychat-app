// ignore_for_file: depend_on_referenced_packages
import 'package:app/page/components.dart';
import 'package:app/page/theme.dart';
import 'package:app/service/qrscan.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:keychat_ecash/components/SelectMint.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart';
import './PayInvoice_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

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
    controller = Get.put(PayInvoiceController(invoice: widget.invoce));
    cashuController = Get.find<EcashController>();
    cashuController.getBalance();
    super.initState();
  }

  @override
  void dispose() {
    Get.delete<PayInvoiceController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            leading: Container(),
            centerTitle: true,
            title: Text('Send to Lightning',
                style: Theme.of(context).textTheme.bodyMedium)),
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
                        Obx(() => FutureBuilder(future: () async {
                              if (controller.selectedInvoice.value.isEmpty) {
                                return null;
                              }
                              try {
                                String invoice =
                                    controller.selectedInvoice.value;
                                if (invoice.startsWith('lightning:')) {
                                  invoice =
                                      invoice.replaceFirst('lightning:', '');
                                }
                                return await rust_cashu.decodeInvoice(
                                    encodedInvoice:
                                        controller.selectedInvoice.value);
                              } catch (e) {
                                return null;
                              }
                            }(), builder: (context, snapshot) {
                              if (snapshot.data == null ||
                                  snapshot.connectionState !=
                                      ConnectionState.done) return Container();
                              InvoiceInfo invoiceInfo =
                                  snapshot.data as InvoiceInfo;
                              return ListTile(
                                title: Text(
                                    '${invoiceInfo.amount} sat - ${invoiceInfo.memo}'),
                                subtitle: textSmallGray(
                                    context,
                                    invoiceInfo.expiryTs.toInt() <
                                            DateTime.now()
                                                .millisecondsSinceEpoch
                                        ? 'Expired'
                                        : 'Expires in ${formatTime(invoiceInfo.expiryTs.toInt())}'),
                              );
                            })),
                        const SizedBox(height: 10),
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
                          child: const Text('Disabled By Mint Server'))),
                ]))));
  }
}
