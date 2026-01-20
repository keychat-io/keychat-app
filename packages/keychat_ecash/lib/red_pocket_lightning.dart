import 'package:keychat/global.dart';
import 'package:keychat/models/embedded/cashu_info.dart';
import 'package:keychat/models/message.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_ecash/status_enum.dart';
import 'package:keychat_ecash/unified_wallet/models/cashu_wallet.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_ecash/nwc/index.dart';

class RedPocketLightning extends StatefulWidget {
  const RedPocketLightning({required this.message, super.key});
  final Message message;

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
      padding: const EdgeInsets.only(top: 8, bottom: 8),
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
        children: [
          ListTile(
            leading: SizedBox(
              width: 48,
              child: Image.asset(
                'assets/images/lightning.png',
                fit: BoxFit.contain,
              ),
            ),
            title: Text(
              _cashuInfoModel.amount > 0
                  ? '${_cashuInfoModel.amount} ${EcashTokenSymbol.sat.name}'
                  : 'Token spent',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            subtitle: Text(
              _cashuInfoModel.token,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
            ),
            trailing: _cashuInfoModel.status == TransactionStatus.pending
                ? null
                : CashuStatus.getStatusIcon(
                    _cashuInfoModel.amount == 0
                        ? TransactionStatus.success
                        : _cashuInfoModel.status,
                  ),
          ),
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
                        'handlePayInvoice', const Duration(seconds: 3),
                        () async {
                      if (_cashuInfoModel.status != TransactionStatus.pending) {
                        return;
                      }
                      final tx =
                          await Get.find<EcashController>().dialogToPayInvoice(
                        input: _cashuInfoModel.token,
                        isPay: true,
                      );
                      logger.d('payToLightning tx: $tx');
                      if (tx == null) return;
                      switch (tx) {
                        case CashuWalletTransaction():
                          updateMessageEcashStatus(tx.rawData.status);
                        case _:
                          updateMessageEcashStatus(TransactionStatus.success);
                      }
                    });
                  },
                  child: Text(
                    'Pay Invoice',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white),
                  ),
                ),
                IconButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _cashuInfoModel.token),
                    );
                    EasyLoading.showSuccess('Token copied to clipboard');
                  },
                  icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                ),
                if (widget.message.isMeSend && _cashuInfoModel.hash != null)
                  IconButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white70),
                    ),
                    onPressed: checkStatus,
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> checkStatus() async {
    final hash = _cashuInfoModel.hash;
    if (hash == null) {
      EasyLoading.showError('No id found');
      return;
    }
    if (_cashuInfoModel.mint.startsWith(KeychatGlobal.nwcPrefix)) {
      final nwcController =
          Utils.getOrPutGetxController(create: NwcController.new);
      final res = await nwcController.lookupInvoice(
        uri: _cashuInfoModel.mint,
        invoice: _cashuInfoModel.token,
      );
      if (res != null) {
        if (res.settledAt != null) {
          await updateMessageEcashStatus(TransactionStatus.success);
          return;
        }
        if (res.expiresAt * 1000 < DateTime.now().millisecondsSinceEpoch) {
          await updateMessageEcashStatus(TransactionStatus.expired);
          return;
        }
      }
      return;
    }
    try {
      logger.d('checkStatus id: $hash');
      final item = await rust_cashu.checkTransaction(id: hash);
      final ln = item;
      await updateMessageEcashStatus(ln.status);
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
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
