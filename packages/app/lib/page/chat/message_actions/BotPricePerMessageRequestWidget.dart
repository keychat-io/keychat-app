import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:app/bot/bot_message_model.dart';
import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
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
  BotMessageModel? bmm;
  @override
  void initState() {
    try {
      Map<String, dynamic> map = jsonDecode(widget.message.content);
      bmm = BotMessageModel.fromJson(map);
    } catch (e) {}
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.confirmResult != null) {
      return NoticeTextWidget.success(
          'Selected: ${widget.message.confirmResult}');
    }
    return bmm == null
        ? const SizedBox()
        : Wrap(
            spacing: 8.0,
            direction: Axis.vertical,
            children: bmm!.priceModels.map((data) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
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
                            widget.message.confirmResult = jsonEncode(data);

                            // save config to local db
                            Map localConfig =
                                jsonDecode(widget.room.botLocalConfig ?? '{}');
                            localConfig[bmm!.type.name] = data;
                            widget.room.botLocalConfig =
                                jsonEncode(localConfig);
                            await RoomService()
                                .updateRoomAndRefresh(widget.room);

                            await MessageService()
                                .updateMessageAndRefresh(widget.message);
                            EasyLoading.showSuccess('Selected: $priceString');
                            // var cmm = ClientMessageModel(
                            //     type: ClientMessageType.selectionResponse,
                            //     message: data.name,
                            //     id: bmm!.id);
                            // await RoomService().sendTextMessage(
                            //     widget.room, jsonEncode(cmm.toJson()),
                            //     realMessage: 'Selected: $priceString');
                            Get.back();
                          },
                          isDefaultAction: true,
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: const TextStyle(fontSize: 16.0),
                    ),
                    Text(
                      '${data.price} sat/message',
                      style:
                          const TextStyle(fontSize: 12.0, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
  }
}
