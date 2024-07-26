import 'dart:async' show Timer;
import 'package:intl/intl.dart' show DateFormat;

import 'package:keychat_ecash/Bills/lightning_bill_controller.dart';
import 'package:keychat_ecash/status_enum.dart';
import 'package:app/page/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rustCashu;

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
    rustCashu.decodeInvoice(encodedInvoice: tx.pr).then((value) {
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
          title: Text(tx.io == TransactionDirection.in_
              ? 'Receive from LN'
              : 'Send to LN'),
        ),
        body: Container(
            height: Get.height,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.center,
              child: Column(children: [
                CashuStatus.getStatusIcon(tx.status, 60),
                if (tx.status == TransactionStatus.pending && expiryTs > 0)
                  Text(
                      'Expire At: ${DateFormat("yyyy-MM-ddTHH:mm:ss").format(DateTime.fromMillisecondsSinceEpoch(expiryTs))}'),
                const SizedBox(
                  height: 15,
                ),
                RichText(
                    text: TextSpan(
                  text: tx.amount.toString(),
                  children: <TextSpan>[
                    TextSpan(
                      text: ' ${EcashTokenSymbol.sat.name}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        height: 1.0,
                        fontSize: 34,
                      ),
                )),
                Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    child: genQRImage(tx.pr,
                        size: 300, embeddedImageSize: 0, embeddedImage: null)),
                if (tx.fee != null)
                  Text('Fee: ${tx.fee} ${EcashTokenSymbol.sat.name}'),
                textSmallGray(context, 'Hash: ${tx.hash}',
                    overflow: TextOverflow.ellipsis),
                textSmallGray(context, 'Mint: ${tx.mint}'),
                textSmallGray(context,
                    'Created At: ${DateTime.fromMillisecondsSinceEpoch(tx.time.toInt()).toIso8601String()}'),
                const SizedBox(
                  height: 20,
                ),
                OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tx.pr));
                      EasyLoading.showToast('Copied');
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Invoice')),
                if (tx.io == TransactionDirection.in_ &&
                    tx.status == TransactionStatus.pending)
                  const Text('To pay with Bitcoin Lightning Wallet'),
              ]),
            )));
  }
}
