import 'package:app/utils.dart';
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
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

class RedPocketCashu extends StatefulWidget {
  final Message message;

  const RedPocketCashu({super.key, required this.message});

  @override
  _RedPocketCashuState createState() => _RedPocketCashuState();
}

class _RedPocketCashuState extends State<RedPocketCashu> {
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
        padding: EdgeInsets.only(top: 8, bottom: 8),
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
                    width: 48,
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white70),
                      ),
                      onPressed: () async {
                        EasyThrottle.throttle(
                            'handleReceiveToken', const Duration(seconds: 3),
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
                            logger.d(
                                'handleReceiveToken status: ${model.status.name}');
                            updateMessageEcashStatus(model.status);
                          }
                        });
                      },
                      child: Text('Redeem',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white))),
                  IconButton(
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white70)),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _cashuInfoModel.token));
                        EasyLoading.showSuccess('Token copied to clipboard');
                      },
                      icon: Icon(Icons.copy, color: Colors.white, size: 16)),
                  if (_cashuInfoModel.id != null)
                    IconButton(
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white70)),
                        onPressed: checkStatus,
                        icon:
                            Icon(Icons.refresh, color: Colors.white, size: 16)),
                ],
              ),
          ],
        ));
  }

  Future<void> checkStatus() async {
    if (_cashuInfoModel.id == null) {
      EasyLoading.showError('No id found');
      return;
    }
    try {
      logger.d('checkStatus id: ${_cashuInfoModel.id}');
      Transaction item =
          await rust_cashu.checkTransaction(id: _cashuInfoModel.id!);
      Transaction ln = item;
      await updateMessageEcashStatus(ln.status);
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      EasyLoading.showError(msg);
      logger.e('checkStatus error: $e', stackTrace: s);
    }
  }

  Future<void> updateMessageEcashStatus(TransactionStatus status) async {
    if (_cashuInfoModel.status == status) {
      EasyLoading.showInfo('Status: ${status.name.toUpperCase()}');
      return;
    }
    _cashuInfoModel.status = status;
    widget.message.cashuInfo = _cashuInfoModel;
    await MessageService.instance.updateMessage(widget.message);
    setState(() {
      _cashuInfoModel = _cashuInfoModel;
    });
  }
}
