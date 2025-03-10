import 'package:keychat_ecash/status_enum.dart';
import 'package:app/page/components.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:timer_builder/timer_builder.dart';

class CreateInvoiceSucessPage extends StatefulWidget {
  final LNTransaction transaction;
  const CreateInvoiceSucessPage({super.key, required this.transaction});

  @override
  State<CreateInvoiceSucessPage> createState() =>
      CreateInvoiceSucessPageState();
}

class CreateInvoiceSucessPageState extends State<CreateInvoiceSucessPage> {
  @override
  Widget build(context) {
    int time = DateTime.now().millisecondsSinceEpoch ~/ 1000 -
        widget.transaction.time.toInt();
    return Scaffold(
        appBar: AppBar(
          title: const Text('Invoice'),
        ),
        body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              CashuStatus.getStatusIcon(widget.transaction.status, 40),
              if (widget.transaction.status == TransactionStatus.pending)
                TimerBuilder.periodic(const Duration(seconds: 2),
                    builder: (context) {
                  time--;
                  if (time <= 0) return const SizedBox();
                  return Text(
                    formatTimeToHHmm(time),
                    style: const TextStyle(fontSize: 24),
                  );
                }),
              textSmallGray(context, widget.transaction.mint),
              const SizedBox(
                height: 15,
              ),
              RichText(
                  text: TextSpan(
                text: widget.transaction.amount.toString(),
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
              Utils.genQRImage(widget.transaction.pr,
                  size: 240, embeddedImageSize: 60, embeddedImage: null),
              Expanded(
                  child: Text(
                maxLines: 3,
                widget.transaction.pr,
                overflow: TextOverflow.ellipsis,
              )),
              SafeArea(
                  child: widget.transaction.status == TransactionStatus.expired
                      ? FilledButton(
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.pink),
                          child: const Text('Expired'))
                      : FilledButton.icon(
                          style: ButtonStyle(
                              minimumSize: WidgetStateProperty.all(
                                  const Size(double.infinity, 44))),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: widget.transaction.pr));
                            EasyLoading.showToast('Copied');
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy')))
            ])));
  }
}
