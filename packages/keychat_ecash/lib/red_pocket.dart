import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

import 'package:app/models/embedded/cashu_info.dart';
import 'package:app/models/message.dart';
import 'package:keychat_ecash/cashu_receive.dart';
import 'package:keychat_ecash/status_enum.dart';
import 'package:app/service/message.service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RedPocket extends StatefulWidget {
  final Message message;

  const RedPocket({super.key, required this.message});

  @override
  _RedPocketState createState() => _RedPocketState();
}

class _RedPocketState extends State<RedPocket> {
  late CashuInfoModel _cashuInfoModel;

  @override
  void initState() {
    super.initState();

    _cashuInfoModel = widget.message.cashuInfo!;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        CashuInfoModel? model = await Get.dialog(CashuReceiveWidget(
          cashuinfo: widget.message.cashuInfo!,
          messageId: widget.message.id,
        ));
        if (model != null) {
          if (model.status != _cashuInfoModel.status) {
            widget.message.cashuInfo = model;
            await MessageService().updateMessage(widget.message);
            setState(() {
              _cashuInfoModel = model;
            });
          }
        }
      },
      child: Container(
          width: 300,
          height: 70,
          // margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 245, 67, 39),
                Color.fromARGB(255, 255, 149, 0)
              ],
            ),
          ),
          child: ListTile(
              leading: const Icon(
                Icons.currency_bitcoin,
                color: Colors.white,
                size: 34,
              ),
              title: Text(
                _cashuInfoModel.amount > 0
                    ? 'Send ${_cashuInfoModel.amount} ${EcashTokenSymbol.sat.name}'
                    : 'Token spent',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _cashuInfoModel.token,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6)),
              ),
              trailing: CashuStatus.getStatusIcon(_cashuInfoModel.amount == 0
                  ? TransactionStatus.success
                  : _cashuInfoModel.status))),
    );
  }
}
