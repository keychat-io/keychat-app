import 'package:app/models/models.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import './NostrEvents_controller.dart';

class NostrEventsPage extends GetView<NostrEventsController> {
  const NostrEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Receive Nostr Events'),
        ),
        body: SafeArea(
            child: Obx(() => ListView.builder(
                itemBuilder: (context, index) {
                  EventLog el = controller.events[index];
                  return ListTile(
                    title: Text(el.eventId, overflow: TextOverflow.ellipsis),
                    subtitle: Wrap(
                      direction: Axis.vertical,
                      children: [
                        Text('Message: ${el.message?.content}'),
                        Text(el.createdAt.toString())
                      ],
                    ),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: el.toString()));
                    },
                  );
                },
                itemCount: controller.events.length))));
  }
}
