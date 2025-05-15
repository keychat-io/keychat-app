import 'package:flutter/services.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

import 'package:app/models/embedded/cashu_info.dart';
import 'package:app/models/message.dart';
import 'package:keychat_ecash/status_enum.dart';
import 'package:app/service/message.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:easy_debounce/easy_throttle.dart';

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
    return Container(
        constraints: const BoxConstraints(maxWidth: 350),
        alignment: Alignment.center,
        padding: EdgeInsets.only(bottom: 8),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ListTile(
                leading: SizedBox(
                    width: 32,
                    child: Image.asset('assets/images/BTC.png',
                        fit: BoxFit.contain)),
                title: Text(
                    _cashuInfoModel.amount > 0
                        ? '${_cashuInfoModel.amount} ${EcashTokenSymbol.sat.name}'
                        : 'Token spent',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white)),
                subtitle: Text(
                  _cashuInfoModel.token,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w400),
                ),
                trailing: _cashuInfoModel.status == TransactionStatus.pending
                    ? null
                    : CashuStatus.getStatusIcon(_cashuInfoModel.amount == 0
                        ? TransactionStatus.success
                        : _cashuInfoModel.status)),
            if (_cashuInfoModel.status == TransactionStatus.pending)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 24,
                children: [
                  OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white70),
                      ),
                      onPressed: () async {
                        EasyThrottle.throttle(
                            'handleReceiveToken', const Duration(seconds: 2),
                            () async {
                          if (_cashuInfoModel.status !=
                              TransactionStatus.pending) {
                            return;
                          }
                          CashuInfoModel? model =
                              await CashuUtil.handleReceiveToken(
                                  token: _cashuInfoModel.token,
                                  messageId: widget.message.id,
                                  retry: true);

                          if (model != null) {
                            if (model.status != _cashuInfoModel.status) {
                              widget.message.cashuInfo = model;
                              await MessageService.instance
                                  .updateMessage(widget.message);
                              setState(() {
                                _cashuInfoModel = model;
                              });
                            }
                          }
                        });
                      },
                      child: Text('Redeem',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white))),
                  OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white70),
                      ),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _cashuInfoModel.token));
                        EasyLoading.showSuccess('Token copied to clipboard');
                      },
                      child: Icon(Icons.copy, color: Colors.white, size: 16)),
                ],
              ),
          ],
        ));
  }
}
