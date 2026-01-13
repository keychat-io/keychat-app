import 'package:keychat/utils.dart';
import 'package:dio/dio.dart' show Dio, DioException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_controller.dart';
import 'package:keychat_ecash/ecash_controller.dart';

class PayToLnurl extends StatefulWidget {
  const PayToLnurl(this.data, {super.key});
  final Map<String, dynamic> data;

  @override
  _PayToLnurlState createState() => _PayToLnurlState();
}

class _PayToLnurlState extends State<PayToLnurl> {
  bool isLoading = false;
  late TextEditingController amountController;
  late Map<String, dynamic> data;
  late EcashController ecashController;
  @override
  void initState() {
    ecashController = Get.find<EcashController>();
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
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Form(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    Text(
                      '${data['domain']} is requesting ${(data['minSendable'] / 1000).round()} and ${(data['maxSendable'] / 1000).round()} sat',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Input Amount(Sats)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                  final tx = await pic.confirmToPayInvoice(
                    invoice: pr,
                    walletSelection: ecashController.selectedWallet.value,
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
                minimumSize: WidgetStateProperty.all(Size(Get.width - 32, 48)),
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
    );
  }
}
