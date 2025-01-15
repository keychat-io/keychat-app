// ignore_for_file: depend_on_referenced_packages

import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

import 'package:keychat_ecash/Bills/lightning_bill_controller.dart';
import 'package:keychat_ecash/Bills/lightning_transaction.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:app/page/components.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class LightningBillPage extends GetView<LightningBillController> {
  const LightningBillPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Lightning Bills'),
        ),
        body: Obx(() => !controller.status.value &&
                controller.transactions.isEmpty
            ? const Center(
                child: SizedBox(
                    width: 100,
                    height: 100,
                    child: SpinKitWave(
                      color: Color.fromARGB(255, 141, 123, 243),
                      size: 40.0,
                    )))
            : Obx(() => SmartRefresher(
                enablePullDown: true,
                onRefresh: () async {
                  await rust_cashu.checkPending();
                  await controller.getTransactions();
                  controller.refreshController.refreshCompleted();
                },
                enablePullUp: true,
                onLoading: () async {
                  await controller.getTransactions(
                      offset: controller.transactions.length);
                  controller.refreshController.loadComplete();
                },
                controller: controller.refreshController,
                child: ListView.separated(
                    separatorBuilder: (BuildContext context, int index) =>
                        Divider(
                          color: Theme.of(context).dividerTheme.color,
                          thickness: 0.2,
                          height: 1,
                        ),
                    itemCount: controller.transactions.length,
                    itemBuilder: (BuildContext context, int index) {
                      LNTransaction transaction =
                          controller.transactions[index];
                      bool isSend = transaction.io == TransactionDirection.out;
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
                          leading: CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  Get.isDarkMode ? Colors.white10 : Colors.grey,
                              child: Icon(
                                isSend
                                    ? CupertinoIcons.arrow_up
                                    : CupertinoIcons.arrow_down,
                                size: 18,
                              )),
                          title: Text(
                              (isSend ? "-" : "+") +
                                  (transaction.amount).toString(),
                              style: Theme.of(context).textTheme.bodyLarge),
                          subtitle: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              textSmallGray(context, transaction.mint),
                              textSmallGray(
                                  Get.context!,
                                  DateTime.fromMillisecondsSinceEpoch(
                                          transaction.time.toInt())
                                      .toIso8601String())
                            ],
                          ),
                          trailing: CashuUtil.getLNIcon(transaction.status));
                    })))));
  }
}
