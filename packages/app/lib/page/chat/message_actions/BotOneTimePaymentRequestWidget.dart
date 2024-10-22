import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:app/bot/bot_client_message_model.dart';
import 'package:app/bot/bot_server_message_model.dart';
import 'package:app/models/embedded/cashu_info.dart';
import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/utils.dart';

class BotOneTimePaymentRequestWidget extends StatefulWidget {
  final Room room;
  final Message message;

  const BotOneTimePaymentRequestWidget(this.room, this.message, {super.key});

  @override
  _BotOneTimePaymentRequestWidgetState createState() =>
      _BotOneTimePaymentRequestWidgetState();
}

class _BotOneTimePaymentRequestWidgetState
    extends State<BotOneTimePaymentRequestWidget> {
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
        border: Border.all(color: Colors.purple.shade600),
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
          if (selected) return;
          Get.dialog(
            CupertinoAlertDialog(
              title: Text(data.name),
              content: Column(
                children: [Text(data.description)],
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
                    EasyThrottle.throttle(
                        'click_perMessagePriceOptionWidget_${widget.message.id}',
                        const Duration(seconds: 3), () async {
                      String? cashuTokenString;
                      if (data.unit == 'sat' && data.price > 0) {
                        try {
                          CashuInfoModel cashuToken = await CashuUtil.getStamp(
                              amount: data.price,
                              token: data.unit,
                              mints: data.mints);
                          cashuTokenString = cashuToken.token;
                        } catch (e, s) {
                          String msg = Utils.getErrorMessage(e);
                          logger.e(msg, error: e, stackTrace: s);
                          EasyLoading.showError(msg);
                          return;
                        }
                      }
                      String confirmResult = jsonEncode(data.toJson());
                      BotClientMessageModel bcm = BotClientMessageModel(
                          type: MessageMediaType.botOneTimePaymentRequest,
                          message: confirmResult,
                          payToken: cashuTokenString);

                      await RoomService().sendTextMessage(
                          widget.room, jsonEncode(bcm.toJson()),
                          realMessage:
                              'Selected ${data.name}, and send ecash: ${data.price} ${data.unit}');

                      widget.message.confirmResult = confirmResult;
                      await MessageService()
                          .updateMessageAndRefresh(widget.message);
                      EasyLoading.showSuccess('Success');
                      Get.back();
                    });
                  },
                  isDefaultAction: true,
                  child: Text('Pay ${data.price} ${data.unit}'),
                ),
              ],
            ),
          );
        },
        subtitle: Wrap(
          direction: Axis.vertical,
          children: [
            Text('${data.price} ${data.unit}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: const Color(0xFFFE4F00))),
            if (data.description.isNotEmpty) Text(data.description)
          ],
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
      ),
    );
  }
}
