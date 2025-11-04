import 'package:keychat/models/embedded/cashu_info.dart';
import 'package:keychat/models/message.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:keychat_ecash/status_enum.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class RedPocketCashu extends StatefulWidget {
  const RedPocketCashu({required this.message, super.key});
  final Message message;

  @override
  _RedPocketCashuState createState() => _RedPocketCashuState();
}

class _RedPocketCashuState extends State<RedPocketCashu> {
  late CashuInfoModel _cashuInfoModel;
  bool _isRedeeming = false;

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
          colors: [
            Color.fromARGB(255, 245, 67, 39),
            Color.fromARGB(255, 255, 149, 0),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ListTile(
            leading: SizedBox(
              width: 48,
              child: Image.asset(
                'assets/images/bitcoin.png',
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
                  onPressed: _isRedeeming
                      ? null
                      : () async {
                          if (_cashuInfoModel.status !=
                                  TransactionStatus.pending ||
                              _isRedeeming) {
                            return;
                          }

                          setState(() {
                            _isRedeeming = true;
                          });

                          try {
                            final model = await EcashUtils.handleReceiveToken(
                              token: _cashuInfoModel.token,
                              messageId: widget.message.id,
                              retry: true,
                            );

                            if (model != null) {
                              await updateMessageEcashStatus(model.status);
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isRedeeming = false;
                              });
                            }
                          }
                        },
                  child: _isRedeeming
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Redeeming...',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                        )
                      : Text(
                          'Redeem',
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
                  icon: const Icon(
                    Icons.copy,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                if (_cashuInfoModel.id != null)
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
    if (_cashuInfoModel.id == null) {
      EasyLoading.showError('No id found');
      return;
    }
    try {
      logger.d('checkStatus id: ${_cashuInfoModel.id}');
      final item = await rust_cashu.checkTransaction(id: _cashuInfoModel.id!);
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
    setState(() {});
  }
}
