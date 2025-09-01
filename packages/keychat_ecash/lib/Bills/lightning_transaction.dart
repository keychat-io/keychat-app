import 'package:app/utils.dart';

import 'package:keychat_ecash/Bills/lightning_bill_controller.dart';
import 'package:keychat_ecash/status_enum.dart';
import 'package:app/page/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

class LightningTransactionPage extends StatefulWidget {
  final Transaction transaction;
  const LightningTransactionPage({super.key, required this.transaction});

  @override
  State<LightningTransactionPage> createState() => _CashuTransactionPageState();
}

class _CashuTransactionPageState extends State<LightningTransactionPage> {
  late Transaction tx;
  int expiryTs = 0;
  LightningBillController? lightningBillController;
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
    lightningBillController =
        Utils.getOrPutGetxController(create: LightningBillController.new);

    lightningBillController?.pendingTaskMap[tx.id] = true;
    lightningBillController?.startCheckPending(tx, expiryTs, (ln) {
      setState(() {
        tx = ln;
      });
    });
  }

  @override
  void dispose() {
    lightningBillController?.stopCheckPending(tx);
    super.dispose();
  }

  @override
  Widget build(context) {
    double maxWidth = MediaQuery.of(context).size.width *
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
            )),
        body: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(children: [
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
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(height: 1.0, fontSize: 34),
                  ))
                ]),
            Padding(
                padding: EdgeInsetsDirectional.symmetric(vertical: 16),
                child: Center(
                    child: Utils.genQRImage('lightning:${tx.token}',
                        size: maxWidth, padding: 16))),
            Center(child: Text('Fee: ${tx.fee.toInt()} ${tx.unit}')),
            if (tx.status == TransactionStatus.pending && expiryTs > 0)
              Text(
                'Expire At: ${formatTime(expiryTs, 'yyyy-MM-dd HH:mm:ss')}',
                textAlign: TextAlign.center,
              ),
            textSmallGray(
              context,
              'Mint: ${tx.mintUrl}',
              textAlign: TextAlign.center,
            ),
            textSmallGray(
              context,
              'Created At: ${DateTime.fromMillisecondsSinceEpoch(tx.timestamp.toInt()).toIso8601String()}',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Wrap(
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              direction: Axis.vertical,
              spacing: 16,
              children: [
                if (tx.io == TransactionDirection.incoming &&
                    tx.status == TransactionStatus.pending)
                  OutlinedButton(
                      style: ButtonStyle(
                          minimumSize:
                              WidgetStateProperty.all(Size(maxWidth, 48))),
                      onPressed: () async {
                        String url = 'lightning:${tx.token}';
                        final Uri uri = Uri.parse(url);
                        bool res = await canLaunchUrl(uri);
                        if (!res) {
                          EasyLoading.showToast('No Lightning wallet found');
                          return;
                        }
                        await launchUrl(uri);
                      },
                      child: const Text('Pay with Lightning wallet')),
                FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: 'lightning:${tx.token}'));
                      EasyLoading.showToast('Copied');
                    },
                    style: ButtonStyle(
                        minimumSize:
                            WidgetStateProperty.all(Size(maxWidth, 48))),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Invoice')),
                const SizedBox(height: 8)
              ],
            )
          ]),
        ));
  }
}
