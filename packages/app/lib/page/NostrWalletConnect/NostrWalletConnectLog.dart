import 'package:app/page/NostrWalletConnect/NostrWalletConnect_controller.dart';
import 'package:app/page/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/state_manager.dart';

class NostrWalletConnectLog extends GetView<NostrWalletConnectController> {
  const NostrWalletConnectLog({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NWC Logs')),
      body: Obx(() => controller.logs.isEmpty
          ? Container()
          : ListView.builder(
              itemCount: controller.logs.length,
              itemBuilder: (context, index) {
                NWCLog log =
                    controller.logs[controller.logs.length - 1 - index];
                bool isSend = [NWCLogMethod.send, NWCLogMethod.subscribe]
                    .contains(log.method);
                return ListTile(
                    dense: true,
                    leading: Icon(
                        isSend ? Icons.arrow_upward : Icons.arrow_downward),
                    title: Text(log.relay),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: log.data));
                      EasyLoading.showToast('Copied');
                    },
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        textSmallGray(context,
                            '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}:${log.time.second.toString().padLeft(2, '0')}.${log.time.millisecond.toString().padLeft(3, '0')}',
                            maxLines: 1),
                        textSmallGray(context, log.data, maxLines: 4),
                      ],
                    ));
              })),
    );
  }
}
