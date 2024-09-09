import 'package:app/models/nostr_event_status.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import './NostrEvents_controller.dart';

class NostrEventsPage extends GetView<NostrEventsController> {
  const NostrEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Failed Events'),
          actions: [
            TextButton(
                onPressed: () async {
                  await controller.deleteAll();
                  EasyLoading.showSuccess('Cleared');
                },
                child: const Text('Clear'))
          ],
        ),
        body: SafeArea(
            child: Obx(() => ListView.builder(
                itemBuilder: (context, index) {
                  NostrEventStatus el = controller.events[index];
                  return ListTile(
                    title: Text(el.eventId, overflow: TextOverflow.ellipsis),
                    subtitle: Wrap(
                      direction: Axis.vertical,
                      children: [
                        Text('Status: ${el.sendStatus.name}'),
                        Text('Relay: ${el.relay}'),
                        if (el.error != null) Text('Error: ${el.error}'),
                        Text(el.createdAt.toString())
                      ],
                    ),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: el.eventId));
                    },
                  );
                },
                itemCount: controller.events.length))));
  }
}
