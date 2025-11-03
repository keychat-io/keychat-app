import 'package:app/page/chat/message_bill/pay_to_relay_controller.dart';
import 'package:app/page/components.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class PayToRelayPage extends StatelessWidget {
  const PayToRelayPage({super.key, this.roomId});
  final int? roomId;

  @override
  Widget build(BuildContext context) {
    final id = roomId ?? int.parse(Get.parameters['id']!);
    final controller = Get.put(PayToRelayController(id));
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Bills Of Chat'),
      ),
      body: Obx(
        () => CustomMaterialIndicator(
          onRefresh: controller.loadMore,
          displacement: 20,
          backgroundColor: Colors.white,
          trigger: IndicatorTrigger.trailingEdge,
          triggerMode: IndicatorTriggerMode.anywhere,
          child: ListView.builder(
            shrinkWrap: true,
            controller: controller.scrollController,
            itemCount: controller.bills.length,
            itemBuilder: (context, index) {
              final bill = controller.bills[index];
              final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
              final formattedDate = formatter.format(bill.createdAt);
              return ListTile(
                key: Key(bill.id.toString()),
                leading: const Icon(CupertinoIcons.arrow_up, color: Colors.red),
                dense: true,
                title: Text('-${bill.ecashAmount} ${bill.ecashName}'),
                subtitle: textSmallGray(context, bill.ecashToken ?? ''),
                trailing: Text(formattedDate),
              );
            },
          ),
        ),
      ),
    );
  }
}
