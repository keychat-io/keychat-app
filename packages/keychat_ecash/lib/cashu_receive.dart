import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:app/models/embedded/cashu_info.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:app/page/components.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:easy_debounce/easy_throttle.dart';

class CashuReceiveWidget extends StatefulWidget {
  const CashuReceiveWidget({
    required this.cashuinfo,
    super.key,
    this.messageId,
  });
  final CashuInfoModel cashuinfo;
  final int? messageId;

  @override
  _CashuReceiveWidgetState createState() => _CashuReceiveWidgetState();
}

class _CashuReceiveWidgetState extends State<CashuReceiveWidget> {
  CashuInfoModel? model;
  String btnStatus = 'Receive';

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Cashu Token'),
      content: Column(
        children: [
          textSmallGray(context, 'Status: ${widget.cashuinfo.status.name}'),
          RichText(
            text: TextSpan(
              text: widget.cashuinfo.amount.toString(),
              children: <TextSpan>[
                TextSpan(
                  text: ' ${EcashTokenSymbol.sat.name}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(height: 1.5, fontSize: 34, color: Colors.green),
            ),
          ),
          Text(widget.cashuinfo.mint),
          Text(
            widget.cashuinfo.token,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          child: widget.cashuinfo.status == TransactionStatus.pending
              ? Text(btnStatus)
              : const Text('Ok'),
          onPressed: () async {
            if (btnStatus == 'OK') {
              Get.back<void>();
              return;
            }
            if (btnStatus == 'Receiving...') {
              return;
            }
            setState(() {
              btnStatus = 'Receiving...';
            });
            EasyThrottle.throttle(
                'handleReceiveToken', const Duration(seconds: 2), () async {
              if (widget.cashuinfo.status != TransactionStatus.pending) {
                Get.back<void>();
                return;
              }
              final model = await EcashUtils.handleReceiveToken(
                token: widget.cashuinfo.token,
                messageId: widget.messageId,
                retry: true,
              );

              Get.back(result: model);
            });
          },
        ),
      ],
    );
  }
}
