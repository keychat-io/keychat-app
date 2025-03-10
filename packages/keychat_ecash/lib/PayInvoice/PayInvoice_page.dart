// ignore_for_file: depend_on_referenced_packages
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
  final bool isPay;
  final bool showScanButton;
  const PayInvoicePage(
      {super.key, this.invoce, this.isPay = false, this.showScanButton = true});

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
            title: Text('Send to Lightning Wallet',
                style: Theme.of(context).textTheme.bodyMedium)),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
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
                        if (widget.isPay == false)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            child: TextField(
                              controller: controller.textController,
                              textInputAction: TextInputAction.done,
                              maxLines: 3,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                  labelText: 'Lightning Invoice or address',
                                  hintText: 'Lightning invoice or address',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.paste),
                                    onPressed: () async {
                                      final clipboardData =
                                          await Clipboard.getData('text/plain');
                                      if (clipboardData == null) return;
                                      final pastedText =
                                          clipboardData.text?.trim() ?? '';
                                      if (pastedText.isNotEmpty) {
                                        controller.textController.text =
                                            pastedText;
                                      }
                                    },
                                  )),
                            ),
                          ),
                        if (widget.showScanButton)
                          OutlinedButton.icon(
                              onPressed: () async {
                                String? result = await QrScanService.instance
                                    .handleQRScan(autoProcess: false);
                                if (result != null) {
                                  controller.textController.text = result;
                                }
                              },
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan')),
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
                                      ConnectionState.done) {
                                return Container();
                              }
                              InvoiceInfo invoiceInfo =
                                  snapshot.data as InvoiceInfo;
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 16),
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${invoiceInfo.amount}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                    fontSize: 34,
                                                    color: Colors.green),
                                          ),
                                          TextSpan(
                                              text: ' sat',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                        ],
                                      ),
                                    ),
                                  ]);
                            })),
                      ],
                    )),
                  ),
                  Obx(() => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: cashuController
                              .supportMint(controller.selectedMint.value)
                          ? FilledButton(
                              style: ButtonStyle(
                                  minimumSize: WidgetStateProperty.all(
                                      const Size(double.infinity, 44))),
                              onPressed: () async {
                                if (GetPlatform.isMobile) {
                                  HapticFeedback.lightImpact();
                                }
                                if (isEmail(controller.textController.text) ||
                                    controller.textController.text
                                        .toLowerCase()
                                        .startsWith('LNURL')) {
                                  var tx = controller.lnurlPayFirst(
                                      controller.textController.text);
                                  if (tx != null) {
                                    Get.back(result: tx);
                                  }
                                  return;
                                }
                                var tx = await controller.confirmToPayInvoice(
                                    invoice:
                                        controller.textController.text.trim(),
                                    mint: controller.selectedMint.value,
                                    isPay: widget.isPay);
                                if (tx != null) {
                                  Get.back(result: tx);
                                }
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
                              child: const Text('Disable By Mint Server')))),
                ]))));
  }
}
