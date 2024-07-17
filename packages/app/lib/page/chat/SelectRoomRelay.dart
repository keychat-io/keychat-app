import 'package:app/global.dart';
import 'package:app/service/websocket.service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SelectRoomRelay extends StatefulWidget {
  final String? current;
  const SelectRoomRelay(this.current, {super.key});

  @override
  _SelectRoomRelayState createState() => _SelectRoomRelayState();
}

class _SelectRoomRelayState extends State<SelectRoomRelay> {
  List<String> relays = [];
  int _selectedRelay = 0;
  @override
  void initState() {
    WebsocketService ws = Get.find<WebsocketService>();
    setState(() {
      relays = ws.getOnlineRelayString();
      int index = relays.indexOf(widget.current ?? KeychatGlobal.defaultRelay);
      if (index > -1) {
        _selectedRelay = index;
      }
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
          title: const Text('Select Relay'),
          actions: [
            FilledButton(
              child: const Text('Done'),
              onPressed: () {
                Get.back(result: relays[_selectedRelay]);
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
                      return RadioListTile<int>(
                        title: Text(relays[index]),
                        value: index,
                        groupValue: _selectedRelay,
                        onChanged: (int? value) {
                          if (value == null) return;

                          setState(() {
                            _selectedRelay = value;
                          });
                        },
                      );
                    },
                  ),
          ),
        ));
  }
}
