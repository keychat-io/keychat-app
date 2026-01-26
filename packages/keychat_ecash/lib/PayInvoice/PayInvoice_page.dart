import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:keychat/page/theme.dart';
import 'package:keychat/service/qrscan.service.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_controller.dart';
import 'package:keychat_ecash/components/SelectMintAndNwc.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/unified_wallet/unified_wallet_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

class PayInvoicePage extends StatefulWidget {
  const PayInvoicePage({
    super.key,
    this.invoce,
    this.isPay = false,
    this.showScanButton = true,
  });
  final String? invoce;
  final bool isPay;
  final bool showScanButton;

  @override
  _PayInvoicePageState createState() => _PayInvoicePageState();
}

class _PayInvoicePageState extends State<PayInvoicePage> {
  late EcashController ecashController;
  late UnifiedWalletController unifiedWalletController;
  late PayInvoiceController controller;

  @override
  void initState() {
    controller = Get.put(PayInvoiceController(invoice: widget.invoce));
    ecashController = Get.find<EcashController>();
    unifiedWalletController = Utils.getOrPutGetxController(
      create: UnifiedWalletController.new,
    );
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
        centerTitle: true,
        title: const Text(
          'Pay Lightning',
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
                    spacing: 16,
                    children: [
                      const SelectMintAndNwc(),
                      TextField(
                        controller: controller.textController,
                        textInputAction: TextInputAction.done,
                        autofocus: widget.invoce == null,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Lightning invoice or LNURL address',
                          hintText: 'Lightning invoice or LNURL address',
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
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Paying Amount: ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      TextSpan(
                                        text: '${invoiceInfo.amount}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontSize: 20,
                                              color: Colors.green,
                                            ),
                                      ),
                                      TextSpan(
                                        text: ' sat',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
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
                () {
                  final selectedWallet = unifiedWalletController.selectedWallet;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: (selectedWallet.protocol == WalletProtocol.cashu &&
                                ecashController
                                    .supportMint(selectedWallet.id)) ||
                            selectedWallet.protocol == WalletProtocol.nwc
                        ? SizedBox(
                            width:
                                GetPlatform.isDesktop ? 200 : double.infinity,
                            height: 44,
                            child: FilledButton(
                              onPressed: controller.isLoading.value
                                  ? null
                                  : () async {
                                      if (GetPlatform.isMobile) {
                                        await HapticFeedback.lightImpact();
                                      }
                                      try {
                                        final input = controller
                                            .textController.text
                                            .trim();
                                        controller.isLoading.value = true;
                                        // lnurl
                                        if (isEmail(
                                              input,
                                            ) ||
                                            input
                                                .toUpperCase()
                                                .startsWith('LNURL')) {
                                          try {
                                            final tx =
                                                await controller.lnurlPayFirst(
                                              input,
                                            );
                                            if (tx != null) {
                                              Get.back(result: tx);
                                            }
                                          } catch (e, s) {
                                            await EasyLoading.showError(
                                              e.toString(),
                                            );
                                            logger.e(
                                              e.toString(),
                                              stackTrace: s,
                                            );
                                          }
                                          return;
                                        }
                                        // invoice
                                        final selectedWallet =
                                            unifiedWalletController
                                                .selectedWallet;

                                        final tx = await controller
                                            .confirmToPayInvoice(
                                          invoice: controller
                                              .textController.text
                                              .trim(),
                                          walletSelection: selectedWallet,
                                          isPay: widget.isPay,
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text('Confirm Pay'),
                            ),
                          )
                        : SizedBox(
                            width:
                                GetPlatform.isDesktop ? 200 : double.infinity,
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
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
