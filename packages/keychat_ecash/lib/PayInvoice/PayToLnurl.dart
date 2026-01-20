import 'package:keychat/utils.dart';
import 'package:dio/dio.dart' show Dio, DioException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_controller.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_ecash/unified_wallet/unified_wallet_controller.dart';

class PayToLnurl extends StatefulWidget {
  const PayToLnurl(this.data, this.input, {super.key});
  final Map<String, dynamic> data;
  final String input;

  @override
  _PayToLnurlState createState() => _PayToLnurlState();
}

class _PayToLnurlState extends State<PayToLnurl> {
  bool isLoading = false;
  late TextEditingController amountController;
  late Map<String, dynamic> data;
  late EcashController ecashController;
  late UnifiedWalletController unifiedWalletController;

  @override
  void initState() {
    ecashController = Get.find<EcashController>();
    unifiedWalletController = Utils.getOrPutGetxController(
      create: UnifiedWalletController.new,
    );
    data = widget.data;
    amountController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          '${data['domain']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Amount range: ${(data['minSendable'] / 1000).round()}-${(data['maxSendable'] / 1000).round()} sat',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Paying to:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.input,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Amount (Sat)',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  if (GetPlatform.isMobile) {
                    await HapticFeedback.lightImpact();
                  }
                  try {
                    if (isLoading) return;
                    setState(() => isLoading = true);
                    String? pr;
                    if (amountController.text.trim().isEmpty) {
                      EasyLoading.showToast(
                        'Amount must be greater than ${(data['minSendable'] / 1000).round()}',
                      );
                      return;
                    }
                    final amount = int.parse(amountController.text.trim());
                    if (amount == 0) {
                      EasyLoading.showToast(
                        'Amount must be greater than ${(data['minSendable'] / 1000).round()}',
                      );
                      return;
                    }
                    if (data['callback'] == null) {
                      EasyLoading.showToast(
                        "Error: server's callback is null",
                      );
                      return;
                    }
                    final url =
                        '${data['callback'] as String}?amount=${amount * 1000}';
                    final res = await Dio().get(url);
                    pr = res.data['pr'] as String?;
                    if (pr == null) {
                      EasyLoading.showToast('Error: get invoice failed');
                      return;
                    }
                    final pic = Utils.getOrPutGetxController(
                      create: PayInvoiceController.new,
                    );
                    final selectedWallet =
                        unifiedWalletController.selectedWallet;
                    if (selectedWallet == null) {
                      EasyLoading.showError('No wallet selected');
                      return;
                    }
                    final tx = await pic.confirmToPayInvoice(
                      invoice: pr,
                      walletSelection: selectedWallet,
                      isPay: true,
                    );
                    Get.back(result: tx);
                  } on DioException catch (e, s) {
                    EasyLoading.showError(
                      e.response?.toString() ?? e.toString(),
                    );
                    logger.e(
                      'initNofityConfig ${e.response}',
                      error: e,
                      stackTrace: s,
                    );
                  } catch (e, s) {
                    logger.e('error: $e', error: e, stackTrace: s);
                    EasyLoading.showError('Error: $e');
                    return;
                  } finally {
                    setState(() => isLoading = false);
                  }
                },
                style: ButtonStyle(
                  minimumSize:
                      WidgetStateProperty.all(Size(Get.width - 32, 48)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
