// ignore_for_file: depend_on_referenced_packages

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:keychat_ecash/Bills/lightning_bill_controller.dart';
import 'package:keychat_ecash/Bills/lightning_transaction.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:app/page/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class LightningBillPage extends GetView<LightningBillController> {
  const LightningBillPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(centerTitle: true, title: const Text('Lightning Bills')),
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
                        onRefresh: () async => await controller.getTransactions(
                            offset: controller.transactions.length),
                        displacement: 20,
                        backgroundColor: Colors.white,
                        trigger: IndicatorTrigger.trailingEdge,
                        triggerMode: IndicatorTriggerMode.anywhere,
                        child: ListView.separated(
                            separatorBuilder: (BuildContext context2,
                                    int index) =>
                                Divider(
                                  color: Theme.of(context).dividerTheme.color,
                                  thickness: 0.2,
                                  height: 1,
                                ),
                            itemCount: controller.transactions.length,
                            itemBuilder: (BuildContext context, int index) {
                              Transaction transaction =
                                  controller.transactions[index];

                              return ListTile(
                                  key: Key(index.toString()),
                                  dense: true,
                                  onTap: () {
                                    if (transaction.status ==
                                        TransactionStatus.expired) {
                                      EasyLoading.showToast('It is expired');
                                      return;
                                    }

                                    if (transaction.status ==
                                        TransactionStatus.failed) {
                                      EasyLoading.showToast('It is failed');
                                      return;
                                    }
                                    Get.to(() => LightningTransactionPage(
                                        transaction: transaction));
                                  },
                                  leading: CashuUtil.getTransactionIcon(
                                      transaction.io),
                                  title: Text(
                                      CashuUtil.getLNAmount(transaction),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge),
                                  subtitle: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      textSmallGray(
                                          context, transaction.mintUrl),
                                      textSmallGray(
                                          Get.context!,
                                          DateTime.fromMillisecondsSinceEpoch(
                                                  transaction.timestamp
                                                          .toInt() *
                                                      1000)
                                              .toIso8601String())
                                    ],
                                  ),
                                  trailing:
                                      CashuUtil.getLNIcon(transaction.status));
                            })))))));
  }
}
