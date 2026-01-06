import 'package:keychat/page/theme.dart';
import 'package:keychat/service/qrscan.service.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_controller.dart';
import 'package:keychat_ecash/components/SelectMintAndNwc.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

class PayInvoicePage extends StatefulWidget {
  const PayInvoicePage({
    super.key,
    this.invoce,
    this.isPay = false,
    this.showScanButton = true,
    this.paidCallback,
  });
  final String? invoce;
  final bool isPay;
  final bool showScanButton;
  final Function? paidCallback;

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
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: Container(),
        centerTitle: true,
        title: Text(
          'Send to Lightning Wallet',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          if (widget.showScanButton &&
              (GetPlatform.isMobile || GetPlatform.isMacOS))
            IconButton(
              onPressed: () async {
                final result = await QrScanService.instance.handleQRScan();
                if (result != null) {
                  controller.textController.text = result;
                }
              },
              icon: const Icon(CupertinoIcons.qrcode_viewfinder),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Expanded(
                child: Form(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      Obx(
                        () => SelectMintAndNwc(
                          controller.selectedWallet.value,
                          (WalletSelection wallet) {
                            controller.updateWallet(wallet);
                            if (wallet.type == WalletType.cashu) {
                              cashuController.latestMintUrl.value = wallet.id;
                            }
                          },
                        ),
                      ),
                      if (!widget.isPay)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: TextField(
                            controller: controller.textController,
                            textInputAction: TextInputAction.done,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Lightning Invoice or address',
                              hintText: 'Lightning invoice or address',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.paste),
                                onPressed: () async {
                                  final clipboardData = await Clipboard.getData(
                                    Clipboard.kTextPlain,
                                  );
                                  if (clipboardData?.text != null) {
                                    controller.textController.text =
                                        clipboardData!.text!;
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      Obx(
                        () => FutureBuilder(
                          future: () async {
                            if (controller.selectedInvoice.value.isEmpty) {
                              return null;
                            }
                            try {
                              var invoice = controller.selectedInvoice.value;
                              if (invoice.startsWith('lightning:')) {
                                invoice = invoice.replaceFirst(
                                  'lightning:',
                                  '',
                                );
                              }
                              return await rust_cashu.decodeInvoice(
                                encodedInvoice:
                                    controller.selectedInvoice.value,
                              );
                            } catch (e) {
                              return null;
                            }
                          }(),
                          builder: (context, snapshot) {
                            if (snapshot.data == null ||
                                snapshot.connectionState !=
                                    ConnectionState.done) {
                              return Container();
                            }
                            final invoiceInfo = snapshot.data!;
                            return Column(
                              children: [
                                const SizedBox(height: 8),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '-${invoiceInfo.amount}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontSize: 34,
                                              color: Colors.green,
                                            ),
                                      ),
                                      TextSpan(
                                        text: ' sat',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Obx(
                () => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: (controller.selectedWallet.value.type ==
                                  WalletType.cashu &&
                              cashuController.supportMint(
                                controller.selectedWallet.value.id,
                              )) ||
                          controller.selectedWallet.value.type == WalletType.nwc
                      ? SizedBox(
                          width: GetPlatform.isDesktop ? 200 : double.infinity,
                          height: 44,
                          child: FilledButton(
                            onPressed: controller.isLoading.value
                                ? null
                                : () async {
                                    if (GetPlatform.isMobile) {
                                      await HapticFeedback.lightImpact();
                                    }
                                    try {
                                      controller.isLoading.value = true;
                                      if (isEmail(
                                            controller.textController.text,
                                          ) ||
                                          controller.textController.text
                                              .toUpperCase()
                                              .startsWith('LNURL')) {
                                        final tx =
                                            await controller.lnurlPayFirst(
                                          controller.textController.text,
                                        );
                                        if (tx != null) {
                                          Get.back(result: tx);
                                        }
                                        return;
                                      }
                                      final tx =
                                          await controller.confirmToPayInvoice(
                                        invoice: controller.textController.text
                                            .trim(),
                                        walletSelection:
                                            controller.selectedWallet.value,
                                        isPay: widget.isPay,
                                        paidCallback: widget.paidCallback,
                                      );
                                      if (tx != null) {
                                        Get.back(result: tx);
                                      }
                                    } finally {
                                      controller.isLoading.value = false;
                                    }
                                  },
                            child: controller.isLoading.value
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
                                : const Text('Pay Invoice'),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
