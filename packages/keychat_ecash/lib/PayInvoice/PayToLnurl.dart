import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart' show Dio, DioException;
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_controller.dart';

class PayToLnurl extends StatefulWidget {
  final Map<String, dynamic> data;
  const PayToLnurl(this.data, {super.key});

  @override
  _PayToLnurlState createState() => _PayToLnurlState();
}

class _PayToLnurlState extends State<PayToLnurl> {
  bool isLoading = false;
  late TextEditingController amountController;
  late Map<String, dynamic> data;
  @override
  void initState() {
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
            child: Column(children: [
              Form(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Expanded(
                  child: Column(
                    children: [
                      Text(
                          '${data['domain']} is requesting ${(data['minSendable'] / 1000).round()} and ${(data['maxSendable'] / 1000).round()} sat',
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Input Amount(Sats)'),
                      ),
                    ],
                  ),
                ),
              ),
              FilledButton(
                  onPressed: () async {
                    if (GetPlatform.isMobile) {
                      HapticFeedback.lightImpact();
                    }
                    try {
                      if (isLoading) return;
                      setState(() => isLoading = true);
                      String? pr;
                      if (amountController.text.trim().isEmpty) {
                        EasyLoading.showToast(
                            'Amount must be greater than ${(data['minSendable'] / 1000).round()}');
                        return;
                      }
                      var amount = int.parse(amountController.text.trim());
                      if (amount == 0) {
                        EasyLoading.showToast(
                            'Amount must be greater than ${(data['minSendable'] / 1000).round()}');
                        return;
                      }
                      if (data['callback'] == null) {
                        EasyLoading.showToast(
                            'Error: server\'s callback is null');
                        return;
                      }
                      String url =
                          data['callback'] + '?amount=${amount * 1000}';
                      var res = await Dio().get(url);
                      pr = res.data['pr'];
                      if (pr == null) {
                        EasyLoading.showToast('Error: get invoice failed');
                        return;
                      }
                      PayInvoiceController pic = Utils.getOrPutGetxController(
                          create: PayInvoiceController.new);
                      var tx = await pic.confirmToPayInvoice(
                          invoice: pr,
                          mint: pic.selectedMint.value,
                          isPay: true);
                      Get.back(result: tx);
                    } on DioException catch (e, s) {
                      EasyLoading.showError(
                          e.response?.toString() ?? e.toString());
                      logger.e('initNofityConfig ${e.response?.toString()}',
                          error: e, stackTrace: s);
                    } catch (e, s) {
                      logger.e('error: ${e.toString()}',
                          error: e, stackTrace: s);
                      EasyLoading.showError('Error: ${e.toString()}');
                      return;
                    } finally {
                      setState(() => isLoading = false);
                    }
                  },
                  style: ButtonStyle(
                      minimumSize:
                          WidgetStateProperty.all(Size(Get.width - 32, 48))),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send'))
            ])));
  }
}
