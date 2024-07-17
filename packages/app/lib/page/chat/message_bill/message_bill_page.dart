import 'package:app/models/message_bill.dart';
import 'package:app/page/components.dart';
import 'package:flutter/cupertino.dart';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'message_bill_controller.dart';

class MessageBillPage extends GetView<MessageBillPageController> {
  final int roomId;
  const MessageBillPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    Get.put(MessageBillPageController(roomId));
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Bills Of Chat'),
      ),
      body: Obx(() => SmartRefresher(
          enablePullDown: true,
          onRefresh: () async {
            await controller.loadMore();
            controller.refreshController.loadComplete();
          },
          controller: controller.refreshController,
          child: ListView.builder(
              shrinkWrap: true,
              controller: controller.scrollController,
              itemCount: controller.bills.length,
              itemBuilder: (context, index) {
                MessageBill bill = controller.bills[index];
                DateFormat formatter = DateFormat('MM-dd HH:mm:ss');
                String formattedDate = formatter.format(bill.createdAt);
                return ListTile(
                  key: Key(bill.id.toString()),
                  leading: const Icon(
                    CupertinoIcons.arrow_up,
                    color: Colors.red,
                  ),
                  dense: true,
                  title: Text("-${bill.amount} ${EcashTokenSymbol.sat.name}"),
                  subtitle: textSmallGray(context, bill.relay),
                  trailing: Text(formattedDate),
                );
              }))),
    );
  }
}
