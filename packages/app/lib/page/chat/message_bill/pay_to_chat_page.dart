import 'package:app/models/nostr_event_status.dart';
import 'package:app/page/components.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/cupertino.dart';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'pay_to_relay_controller.dart';

class PayToChatBillPage extends StatelessWidget {
  final int roomId;
  const PayToChatBillPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    PayToRelayController controller = Get.put(PayToRelayController(roomId));
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Bills Of Chat'),
      ),
      body: Obx(() => CustomMaterialIndicator(
          onRefresh: () => controller.loadMore(),
          displacement: 20,
          backgroundColor: Colors.white,
          trigger: IndicatorTrigger.trailingEdge,
          triggerMode: IndicatorTriggerMode.anywhere,
          child: ListView.builder(
              shrinkWrap: true,
              controller: controller.scrollController,
              itemCount: controller.bills.length,
              itemBuilder: (context, index) {
                NostrEventStatus bill = controller.bills[index];
                DateFormat formatter = DateFormat('MM-dd HH:mm:ss');
                String formattedDate = formatter.format(bill.createdAt);
                return ListTile(
                  key: Key(bill.id.toString()),
                  leading:
                      const Icon(CupertinoIcons.arrow_up, color: Colors.red),
                  dense: true,
                  title: Text("-${bill.ecashAmount} ${bill.ecashName}"),
                  subtitle: textSmallGray(context, bill.ecashMint ?? ''),
                  trailing: Text(formattedDate),
                );
              }))),
    );
  }
}
