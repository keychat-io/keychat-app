import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/rust_api.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_ecash/status_enum.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class CashuTransactionPage extends StatefulWidget {
  const CashuTransactionPage({required this.transaction, super.key});
  final Transaction transaction;

  @override
  State<CashuTransactionPage> createState() => _CashuTransactionPageState();
}

class _CashuTransactionPageState extends State<CashuTransactionPage> {
  late Transaction tx;
  bool _isChecking = false;

  @override
  void initState() {
    tx = widget.transaction;
    super.initState();
    if (tx.status != TransactionStatus.pending) return;

    EcashUtils.startCheckPending(tx, (ln) {
      setState(() {
        tx = ln;
      });
    });
  }

  @override
  void dispose() {
    EcashUtils.stopCheckPending(tx);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = Get.width * (Get.width > 500 ? 0.4 : 1) - 32;
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Cashu Transaction')),
      body: Padding(
        padding: const EdgeInsetsGeometry.symmetric(horizontal: 8),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            width: double.infinity,
            padding: GetPlatform.isDesktop
                ? const EdgeInsets.all(8)
                : EdgeInsets.zero,
            child: ListView(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CashuStatus.getStatusIcon(tx.status, 40),
                    const SizedBox(width: 10),
                    RichText(
                      text: TextSpan(
                        text: tx.amount.toString(),
                        children: <TextSpan>[
                          TextSpan(
                            text: ' ${EcashTokenSymbol.sat.name}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              height: 1,
                              fontSize: 40,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (tx.token.length < 3000)
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.symmetric(vertical: 16),
                    child: Center(
                      child: Utils.genQRImage(
                        tx.token,
                        size: maxWidth,
                      ),
                    ),
                  ),
                if (tx.fee != BigInt.from(0))
                  Text(
                    '${tx.io == TransactionDirection.outgoing ? "Mint Send" : (tx.io == TransactionDirection.split ? "Split Send" : "Mint Receive")} Fee: ${tx.fee} ${tx.unit}',
                    textAlign: TextAlign.center,
                  ),
                textSmallGray(
                  context,
                  formatTime(tx.timestamp.toInt() * 1000),
                  textAlign: TextAlign.center,
                ),
                textSmallGray(
                  context,
                  tx.mintUrl,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  tx.token,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  direction: Axis.vertical,
                  spacing: 16,
                  children: [
                    if (tx.status != TransactionStatus.success)
                      OutlinedButton(
                        style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all(
                            Size(maxWidth, 48),
                          ),
                        ),
                        onPressed: _isChecking
                            ? null
                            : () async {
                                if (_isChecking) return;
                                setState(() {
                                  _isChecking = true;
                                });
                                try {
                                  await EasyLoading.show(status: 'Checking...');
                                  final checkedTx = await rust_cashu
                                      .checkTransaction(id: tx.id);
                                  setState(() {
                                    tx = checkedTx;
                                  });
                                  EasyLoading.showSuccess('Checked');
                                } catch (e) {
                                  final msg = Utils.getErrorMessage(e);
                                  await EasyLoading.dismiss();
                                  await Get.dialog<void>(
                                    CupertinoAlertDialog(
                                      title: const Text('Error'),
                                      content: Text(msg),
                                      actions: [
                                        CupertinoDialogAction(
                                          onPressed: Get.back,
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                } finally {
                                  setState(() {
                                    _isChecking = false;
                                  });
                                }
                              },
                        child: const Text('Check Status'),
                      ),
                    if (tx.status == TransactionStatus.pending)
                      OutlinedButton.icon(
                        icon: const Icon(CupertinoIcons.arrow_down),
                        style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all(
                            Size(maxWidth, 48),
                          ),
                        ),
                        onPressed: () async {
                          EasyThrottle.throttle('Receiving_ecash',
                              const Duration(milliseconds: 2000), () async {
                            try {
                              EasyLoading.show(status: 'Receiving...');
                              final cm = await RustAPI.receiveToken(
                                encodedToken: tx.token,
                              );
                              if (cm.status == TransactionStatus.success) {
                                EasyLoading.showSuccess('Success');
                                final tx1 = Transaction(
                                  id: tx.id,
                                  status: cm.status,
                                  io: tx.io,
                                  timestamp: tx.timestamp,
                                  amount: tx.amount,
                                  mintUrl: tx.mintUrl,
                                  token: tx.token,
                                  kind: TransactionKind.cashu,
                                  fee: tx.fee,
                                  metadata: {},
                                );
                                Get.find<EcashController>()
                                  ..getBalance()
                                  ..getRecentTransactions();
                                setState(() {
                                  tx = tx1;
                                });
                              }
                            } catch (e) {
                              EasyLoading.dismiss();
                              final msg = Utils.getErrorMessage(e);

                              EasyLoading.showToast(msg);
                            }
                          });
                        },
                        label: const Text('Receive'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
