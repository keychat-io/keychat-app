// ignore_for_file: depend_on_referenced_packages

import 'package:keychat_ecash/Bills/ecash_bill_controller.dart';
import 'package:keychat_ecash/Bills/cashu_transaction.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rustCashu;

import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:app/page/components.dart';
import 'package:app/rust_api.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

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
                    for (var tx in controller.transactions) {
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
                                children: errors
                                    .map((e) => Text(
                                          e,
                                        ))
                                    .toList(),
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
                  await rustCashu.checkPending();
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
                          height: 0.1,
                        ),
                    itemCount: controller.transactions.length,
                    itemBuilder: (BuildContext context, int index) {
                      CashuTransaction transaction =
                          controller.transactions[index];
                      bool isSend = transaction.io == TransactionDirection.out;
                      return ListTile(
                          key: Key(index.toString()),
                          dense: true,
                          onTap: () {
                            if (transaction.status ==
                                TransactionStatus.failed) {
                              EasyLoading.showToast('It is failed');
                              return;
                            }
                            Get.to(() =>
                                CashuTransactionPage(transaction: transaction));
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
                          subtitle: Wrap(
                            direction: Axis.vertical,
                            children: [
                              textSmallGray(context, transaction.mint),
                              textSmallGray(
                                  Get.context!,
                                  DateTime.fromMillisecondsSinceEpoch(
                                          transaction.time.toInt())
                                      .toString())
                            ],
                          ),
                          trailing:
                              CashuUtil.getStatusIcon(transaction.status));
                    })))));
  }
}
