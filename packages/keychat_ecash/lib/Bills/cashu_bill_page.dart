// ignore_for_file: depend_on_referenced_packages

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:keychat_ecash/Bills/ecash_bill_controller.dart';
import 'package:keychat_ecash/Bills/cashu_transaction.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:app/page/components.dart';
import 'package:app/rust_api.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

class CashuBillPage extends GetView<EcashBillController> {
  const CashuBillPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Cashu Bills'),
          actions: [
            TextButton(
                onPressed: () async {
                  try {
                    EasyLoading.show(status: 'Receiving...');
                    int success = 0;
                    int failed = 0;
                    List<String> errors = [];
                    var list = await rust_cashu.getCashuPendingTransactions();
                    for (var tx in list) {
                      if (tx.status == TransactionStatus.pending) {
                        try {
                          await RustAPI.receiveToken(encodedToken: tx.token);
                          success++;
                        } catch (e, s) {
                          String msg = Utils.getErrorMessage(e);
                          errors.add(msg);
                          failed++;
                          logger.e('receive error', error: e, stackTrace: s);
                        }
                      }
                    }
                    EasyLoading.dismiss();
                    Get.dialog(CupertinoAlertDialog(
                        title: const Text('Receive Result'),
                        content: Column(
                          children: [
                            Text('Success: $success'),
                            Text('Failed: $failed'),
                            if (errors.isNotEmpty)
                              Column(
                                children: errors.map((e) => Text(e)).toList(),
                              )
                          ],
                        ),
                        actions: [
                          CupertinoDialogAction(
                              onPressed: () {
                                Get.back();
                              },
                              child: const Text('OK'))
                        ]));

                    await controller.getTransactions();
                    Get.find<EcashController>().getBalance();
                  } catch (e, s) {
                    EasyLoading.showToast('Receive failed');
                    logger.e(e.toString(), error: e, stackTrace: s);
                  } finally {
                    Future.delayed(const Duration(seconds: 2))
                        .then((value) => EasyLoading.dismiss());
                  }
                },
                child: const Text('Receive Pendings'))
          ],
        ),
        body: Center(
            child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                width: double.infinity,
                padding: GetPlatform.isDesktop
                    ? const EdgeInsets.all(8)
                    : const EdgeInsets.all(0),
                child: Obx(() => !controller.status.value &&
                        controller.transactions.isEmpty
                    ? const Center(
                        child: SizedBox(
                            width: 100,
                            height: 100,
                            child: SpinKitWave(
                              color: Color.fromARGB(255, 141, 123, 243),
                              size: 40.0,
                            )))
                    : Obx(() => CustomMaterialIndicator(
                        onRefresh: () async {
                          int offset = controller.transactions.length;
                          if (controller.indicatorController.edge ==
                              IndicatorEdge.leading) {
                            offset = 0;
                          }
                          await controller.getTransactions(offset: offset);
                        },
                        displacement: 20,
                        backgroundColor: Colors.white,
                        trigger: IndicatorTrigger.bothEdges,
                        triggerMode: IndicatorTriggerMode.anywhere,
                        controller: controller.indicatorController,
                        child: ListView.separated(
                            separatorBuilder: (BuildContext context2,
                                    int index) =>
                                Divider(
                                  color: Theme.of(context).dividerTheme.color,
                                  thickness: 0.2,
                                  height: 0.1,
                                ),
                            itemCount: controller.transactions.length,
                            itemBuilder: (BuildContext context, int index) {
                              Transaction transaction =
                                  controller.transactions[index];
                              String feeString =
                                  'Fee: ${transaction.fee} ${transaction.unit}';
                              return ListTile(
                                  key: Key(index.toString()),
                                  dense: true,
                                  onTap: () {
                                    if (transaction.status ==
                                        TransactionStatus.failed) {
                                      EasyLoading.showToast('It is failed');
                                      return;
                                    }
                                    Get.to(() => CashuTransactionPage(
                                        transaction: transaction));
                                  },
                                  leading: CashuUtil.getTransactionIcon(
                                      transaction.io),
                                  title: Text(
                                      CashuUtil.getCashuAmount(transaction),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge),
                                  subtitle: textSmallGray(Get.context!,
                                      '$feeString - ${formatTime(transaction.timestamp.toInt() * 1000)}'),
                                  trailing: CashuUtil.getStatusIcon(
                                      transaction.status));
                            })))))));
  }
}
