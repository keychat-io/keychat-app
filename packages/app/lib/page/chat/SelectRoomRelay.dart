import 'package:app/service/websocket.service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SelectRoomRelay extends StatefulWidget {
  final List<String> currents;
  const SelectRoomRelay(this.currents, {super.key});

  @override
  _SelectRoomRelayState createState() => _SelectRoomRelayState();
}

class _SelectRoomRelayState extends State<SelectRoomRelay> {
  List<String> relays = [];
  Set<String> selectedRelays = {};
  @override
  void initState() {
    WebsocketService ws = Get.find<WebsocketService>();
    setState(() {
      relays = ws.getActiveRelayString();
      selectedRelays = Set<String>.from(widget.currents)
          .where((relay) => relays.contains(relay))
          .toSet();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Get.back();
            },
          ),
          centerTitle: true,
          title: const Text('Select Receving Relays'),
          actions: [
            FilledButton(
              child: const Text('Done'),
              onPressed: () {
                Get.back(result: selectedRelays.toList());
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: relays.isEmpty
                ? const Text('No any connected relay')
                : ListView.builder(
                    itemCount: relays.length,
                    itemBuilder: (context, index) {
                      return CheckboxListTile(
                        title: Text(relays[index]),
                        value: selectedRelays.contains(relays[index]),
                        onChanged: (bool? value) {
                          if (value == null) return;

                          setState(() {
                            if (value) {
                              selectedRelays.add(relays[index]);
                            } else {
                              selectedRelays.remove(relays[index]);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ));
  }
}
