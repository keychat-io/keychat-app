import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:app/bot/bot_server_message_model.dart';
import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class BotPricePerMessageRequestWidget extends StatefulWidget {
  final Room room;
  final Message message;

  const BotPricePerMessageRequestWidget(this.room, this.message, {super.key});

  @override
  _BotPricePerMessageRequestWidgetState createState() =>
      _BotPricePerMessageRequestWidgetState();
}

class _BotPricePerMessageRequestWidgetState
    extends State<BotPricePerMessageRequestWidget> {
  BotServerMessageModel? bmm;
  @override
  void initState() {
    try {
      Map<String, dynamic> map = jsonDecode(widget.message.content);
      bmm = BotServerMessageModel.fromJson(map);
    } catch (e) {}
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.confirmResult != null) {
      Map<String, dynamic> selected =
          (jsonDecode(widget.message.confirmResult!) as Map<String, dynamic>);
      return perMessagePriceOptionWidget(BotMessageData.fromJson(selected),
          selected: true);
    }
    return bmm == null
        ? const SizedBox()
        : Column(children: [
            ...bmm!.priceModels.map((data) {
              int index = (bmm!.priceModels.indexOf(data) + 1);
              return perMessagePriceOptionWidget(data, index: index);
            })
          ]);
  }

  Container perMessagePriceOptionWidget(BotMessageData data,
      {int index = 1, bool selected = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: ListTile(
          leading: CircleAvatar(
            radius: 16,
            child: Text(index.toString()),
          ),
          dense: true,
          minVerticalPadding: 4,
          title: Text(data.name, style: Theme.of(context).textTheme.titleSmall),
          onTap: () {
            String priceString = '${data.price} ${data.unit}';
            Get.dialog(
              CupertinoAlertDialog(
                title: Text(data.name),
                content: Column(
                  children: [
                    Text(data.description),
                    const Text(
                        'For each message sent to the bot, you need to pay:'),
                    Text(priceString,
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () {
                      Get.back();
                    },
                    child: const Text('Cancel'),
                  ),
                  CupertinoDialogAction(
                    onPressed: () async {
                      if (selected) return;

                      widget.message.confirmResult = jsonEncode(data);

                      // save config to local db
                      Map localConfig =
                          jsonDecode(widget.room.botLocalConfig ?? '{}');
                      localConfig[bmm!.type.name] = data;
                      widget.room.botLocalConfig = jsonEncode(localConfig);
                      await RoomService().updateRoomAndRefresh(widget.room);

                      await MessageService()
                          .updateMessageAndRefresh(widget.message);
                      EasyLoading.showSuccess('Success');
                      Get.back();
                    },
                    isDefaultAction: true,
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            );
          },
          subtitle: Wrap(
            direction: Axis.vertical,
            children: [
              Text('${data.price} ${data.unit} /message',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: const Color(0xFFFE4F00))),
              if (data.description.isNotEmpty) Text(data.description)
            ],
          ),
          trailing: selected
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.check_circle, color: Colors.grey)),
    );
  }
}
