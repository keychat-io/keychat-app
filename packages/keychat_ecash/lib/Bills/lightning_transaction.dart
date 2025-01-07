import 'package:app/utils.dart';

import 'package:keychat_ecash/Bills/lightning_bill_controller.dart';
import 'package:keychat_ecash/status_enum.dart';
import 'package:app/page/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

class LightningTransactionPage extends StatefulWidget {
  final LNTransaction transaction;
  const LightningTransactionPage({super.key, required this.transaction});

  @override
  State<LightningTransactionPage> createState() => _CashuTransactionPageState();
}

class _CashuTransactionPageState extends State<LightningTransactionPage> {
  late LNTransaction tx;
  int expiryTs = 0;
  LightningBillController? lightningBillController;
  @override
  void initState() {
    tx = widget.transaction;
    rust_cashu.decodeInvoice(encodedInvoice: tx.pr).then((value) {
      setState(() {
        expiryTs = value.expiryTs.toInt();
      });
    });

    super.initState();

    if (tx.status != TransactionStatus.pending) return;

    try {
      lightningBillController = Get.find<LightningBillController>();
    } catch (e) {
      lightningBillController = Get.put(LightningBillController());
    }
    lightningBillController!.pendingTaskMap[tx.hash] = true;
    lightningBillController!.startCheckPending(tx, expiryTs, (ln) {
      setState(() {
        tx = ln;
      });
    });
  }

  @override
  void dispose() {
    lightningBillController?.pendingTaskMap[tx.hash] = false;
    super.dispose();
  }

  @override
  Widget build(context) {
    return Scaffold(
        appBar: AppBar(
            centerTitle: true,
            title: Text(tx.io == TransactionDirection.in_
                ? 'Receive from Lightning'
                : 'Send to Lightning')),
        bottomNavigationBar: SafeArea(
            child: Wrap(
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          direction: Axis.vertical,
          spacing: 8,
          children: [
            if (tx.io == TransactionDirection.in_ &&
                tx.status == TransactionStatus.pending)
              FilledButton(
                  onPressed: () async {
                    String url = 'lightning:${tx.pr}';
                    logger.d(url);
                    final Uri uri = Uri.parse(url);
                    await launchUrl(uri);
                  },
                  child: const Text('Authorize Payment in Wallet')),
            OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'lightning:${tx.pr}'));
                  EasyLoading.showToast('Copied');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Invoice')),
          ],
        )),
        body: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.center,
              child: Column(children: [
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
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: genQRImage('lightning:${tx.pr}',
                            size: Get.width - 32,
                            embeddedImageSize: 0,
                            embeddedImage: null))),
                if (tx.fee != null)
                  Text('Fee: ${tx.fee} ${EcashTokenSymbol.sat.name}'),
                if (tx.status == TransactionStatus.pending && expiryTs > 0)
                  Text(
                      'Expire At: ${formatTime(expiryTs, 'yyyy-MM-dd HH:mm:ss')}'),
                textSmallGray(context, 'Mint: ${tx.mint}'),
                textSmallGray(context,
                    'Created At: ${DateTime.fromMillisecondsSinceEpoch(tx.time.toInt()).toIso8601String()}'),
              ]),
            )));
  }
}
