import 'package:app/utils.dart';
import 'package:keychat_ecash/Bills/ecash_bill_controller.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:app/models/embedded/cashu_info.dart';
import 'package:keychat_ecash/status_enum.dart';
import 'package:app/page/components.dart';
import 'package:app/rust_api.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class CashuTransactionPage extends StatefulWidget {
  final CashuTransaction transaction;
  const CashuTransactionPage({super.key, required this.transaction});

  @override
  State<CashuTransactionPage> createState() => _CashuTransactionPageState();
}

class _CashuTransactionPageState extends State<CashuTransactionPage> {
  late CashuTransaction tx;
  @override
  void initState() {
    tx = widget.transaction;
    super.initState();
    if (tx.status != TransactionStatus.pending) return;

    late EcashBillController ecashBillController;
    try {
      ecashBillController = Get.find<EcashBillController>();
    } catch (e) {
      ecashBillController = Get.put(EcashBillController());
    }
    ecashBillController.startCheckPending(tx, (ln) {
      setState(() {
        tx = ln;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Ecash Transaction'),
        ),
        bottomNavigationBar: SafeArea(
            child: Wrap(
                runAlignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                direction: Axis.vertical,
                spacing: 16,
                children: [
              if (tx.status == TransactionStatus.pending)
                FilledButton.icon(
                    icon: const Icon(CupertinoIcons.arrow_down),
                    style: ButtonStyle(
                        minimumSize:
                            WidgetStateProperty.all(Size(Get.width - 32, 48))),
                    onPressed: () async {
                      try {
                        EasyLoading.show(status: 'Receiving...');
                        CashuInfoModel cm =
                            await RustAPI.receiveToken(encodedToken: tx.token);
                        if (cm.status == TransactionStatus.success) {
                          EasyLoading.showSuccess('Success');
                          CashuTransaction tx1 = CashuTransaction(
                              id: tx.id,
                              status: cm.status,
                              io: tx.io,
                              time: tx.time,
                              amount: tx.amount,
                              mint: tx.mint,
                              token: tx.token);
                          Get.find<EcashController>().getBalance();
                          getGetxController<EcashBillController>()
                              ?.getTransactions();
                          setState(() {
                            tx = tx1;
                          });
                        }
                      } catch (e) {
                        EasyLoading.dismiss();
                        String msg = Utils.getErrorMessage(e);

                        EasyLoading.showToast(msg);
                      }
                    },
                    label: const Text('Receive')),
              OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: tx.token));
                    EasyLoading.showToast('Copied');
                  },
                  style: ButtonStyle(
                      minimumSize:
                          WidgetStateProperty.all(Size(Get.width - 32, 48))),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Token')),
            ])),
        body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
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
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          height: 1.0,
                          fontSize: 40,
                        ),
                  )),
                ],
              ),
              if (tx.token.length < 4000)
                Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: genQRImage(tx.token,
                            size: Get.width - 32,
                            embeddedImageSize: 0,
                            embeddedImage: null))),
              textSmallGray(context, tx.mint),
              Text(
                maxLines: tx.token.length < 4000 ? 1 : 3,
                tx.token,
                overflow: TextOverflow.ellipsis,
              )
            ])));
  }
}
