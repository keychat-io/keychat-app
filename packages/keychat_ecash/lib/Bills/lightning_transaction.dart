import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/Bills/lightning_utils.dart.dart';
import 'package:keychat_ecash/status_enum.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:url_launcher/url_launcher.dart';

class LightningTransactionPage extends StatefulWidget {
  const LightningTransactionPage({required this.transaction, super.key});
  final Transaction transaction;

  @override
  State<LightningTransactionPage> createState() => _CashuTransactionPageState();
}

class _CashuTransactionPageState extends State<LightningTransactionPage> {
  late Transaction tx;
  int expiryTs = 0;
  bool _isChecking = false;

  @override
  void initState() {
    tx = widget.transaction;
    rust_cashu.decodeInvoice(encodedInvoice: tx.token).then((value) {
      setState(() {
        expiryTs = value.expiryTs.toInt();
      });
    });

    super.initState();

    if (tx.status != TransactionStatus.pending) return;

    LightningUtils.instance.pendingTaskMap[tx.id] = true;
    LightningUtils.instance.startCheckPending(tx, expiryTs, (ln) {
      setState(() {
        tx = ln;
      });
    });
  }

  @override
  void dispose() {
    LightningUtils.instance.stopCheckPending(tx);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width *
            (MediaQuery.of(context).size.width > 500 ? 0.4 : 1) -
        32;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          tx.io == TransactionDirection.incoming
              ? 'Receive from Lightning Wallet'
              : 'Send to Lightning Wallet',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 10,
              children: [
                CashuStatus.getStatusIcon(tx.status, 40),
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
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(height: 1, fontSize: 34),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
              child: Center(
                child: Utils.genQRImage(
                  'lightning:${tx.token}',
                  size: maxWidth,
                  padding: 16,
                ),
              ),
            ),
            Center(child: Text('Fee: ${tx.fee.toInt()} ${tx.unit}')),
            if (tx.status == TransactionStatus.pending && expiryTs > 0)
              Text(
                'Expire At: ${formatTime(expiryTs)}',
                textAlign: TextAlign.center,
              ),
            textSmallGray(
              context,
              'Mint: ${tx.mintUrl}',
              textAlign: TextAlign.center,
            ),
            textSmallGray(
              context,
              'Created At: ${DateTime.fromMillisecondsSinceEpoch(tx.timestamp.toInt() * 1000).toIso8601String()}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
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
                              final checkedTx =
                                  await rust_cashu.checkTransaction(id: tx.id);
                              setState(() {
                                tx = checkedTx;
                              });
                              await EasyLoading.showSuccess('Checked');
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
                if (tx.io == TransactionDirection.incoming &&
                    tx.status == TransactionStatus.pending)
                  OutlinedButton(
                    style: ButtonStyle(
                      minimumSize: WidgetStateProperty.all(Size(maxWidth, 48)),
                    ),
                    onPressed: () async {
                      final url = 'lightning:${tx.token}';
                      final uri = Uri.parse(url);
                      final res = await canLaunchUrl(uri);
                      if (!res) {
                        EasyLoading.showToast('No Lightning wallet found');
                        return;
                      }
                      await launchUrl(uri);
                    },
                    child: const Text('Pay with Lightning wallet'),
                  ),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: 'lightning:${tx.token}'),
                    );
                    EasyLoading.showToast('Copied');
                  },
                  style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(Size(maxWidth, 48)),
                  ),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Invoice'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
