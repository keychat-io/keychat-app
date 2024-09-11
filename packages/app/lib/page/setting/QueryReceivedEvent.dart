import 'package:app/models/db_provider.dart';
import 'package:app/models/nostr_event_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:isar/isar.dart';

class QueryReceivedEvent extends StatefulWidget {
  const QueryReceivedEvent({super.key});

  @override
  _QueryReceivedEventState createState() => _QueryReceivedEventState();
}

class _QueryReceivedEventState extends State<QueryReceivedEvent> {
  final TextEditingController _controller = TextEditingController();
  List<NostrEventStatus> _results = [];

  void _onSearchChanged() async {
    String query = _controller.text;
    List<NostrEventStatus> list = await DBProvider.database.nostrEventStatus
        .filter()
        .eventIdEqualTo(query)
        .findAll();
    setState(() {
      _results = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Query Received Event')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                  labelText: 'Input Nostr Event Id',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: () async {
                      final clipboardData =
                          await Clipboard.getData('text/plain');
                      if (clipboardData != null) {
                        final pastedText = clipboardData.text;
                        if (pastedText != null && pastedText != '') {
                          _controller.text = pastedText;
                          _onSearchChanged();
                        }
                      }
                    },
                  )),
              onChanged: (value) => _onSearchChanged(),
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  NostrEventStatus nes = _results[index];
                  return ListTile(
                    title: Text(nes.eventId),
                    leading: CircleAvatar(child: Text((index + 1).toString())),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nes.sendStatus.name.toUpperCase()),
                        Text(
                            '${nes.isReceive ? 'Receive From: ' : 'Send To:'} ${nes.relay}'),
                        Text(nes.createdAt.toIso8601String()),
                        if (nes.isReceive) Text(nes.error ?? ''),
                        GestureDetector(
                            onTap: () {
                              String? text =
                                  nes.rawEvent ?? nes.receiveSnapshot;
                              if (text != null) {
                                Clipboard.setData(ClipboardData(text: text));
                                EasyLoading.showSuccess('');
                              }
                            },
                            child: Text(
                                nes.rawEvent ?? nes.receiveSnapshot ?? "")),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
