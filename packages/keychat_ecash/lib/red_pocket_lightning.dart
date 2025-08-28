import 'package:app/utils.dart' show logger;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

import 'package:app/models/embedded/cashu_info.dart';
import 'package:app/models/message.dart';
import 'package:keychat_ecash/status_enum.dart';
import 'package:app/service/message.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:easy_debounce/easy_throttle.dart';

class RedPocketLightning extends StatefulWidget {
  final Message message;

  const RedPocketLightning({super.key, required this.message});

  @override
  _RedPocketLightningState createState() => _RedPocketLightningState();
}

class _RedPocketLightningState extends State<RedPocketLightning> {
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
            colors: [Color(0xFF380F49), Color(0xFF123678), Color(0xFF7D3D15)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ListTile(
                leading: SizedBox(
                    width: 32,
                    child: Image.asset('assets/images/lightning.png',
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
                            'handlePayInvoice', const Duration(seconds: 2),
                            () async {
                          if (_cashuInfoModel.status !=
                              TransactionStatus.pending) {
                            return;
                          }
                          var tx = await Get.find<EcashController>()
                              .proccessPayLightningBill(_cashuInfoModel.token,
                                  isPay: true);
                          if (tx == null) return;
                          var lnTx = tx.field0 as LNTransaction;
                          logger.i('LN Transaction:   Amount=${lnTx.amount}, '
                              'INfo=${lnTx.info}, Description=${lnTx.fee}, '
                              'Hash=${lnTx.hash}, NodeId=${lnTx.status.name}');

                          _cashuInfoModel.status = lnTx.status;
                          widget.message.cashuInfo = _cashuInfoModel;
                          await MessageService.instance
                              .updateMessage(widget.message);
                          setState(() {
                            _cashuInfoModel = _cashuInfoModel;
                          });
                        });
                      },
                      child: Text('Pay Invoice',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white))),
                  OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white70)),
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
