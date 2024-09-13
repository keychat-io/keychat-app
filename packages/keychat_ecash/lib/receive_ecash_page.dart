import 'package:app/service/qrscan.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:flutter_easyloading/flutter_easyloading.dart';

class ReceiveEcash extends StatefulWidget {
  const ReceiveEcash({super.key});

  @override
  _ReceiveEcashState createState() => _ReceiveEcashState();
}

class _ReceiveEcashState extends State<ReceiveEcash> {
  EcashController controller = Get.find<EcashController>();
  late TextEditingController receiveTextController;
  rust_cashu.TokenInfo? decodedModel;
  bool supported = true;
  @override
  void initState() {
    receiveTextController = TextEditingController();
    receiveTextController.addListener(() async {
      String? text = receiveTextController.text.trim();
      if (text.isNotEmpty) {
        try {
          var res = await rust_cashu.decodeToken(encodedToken: text);

          setState(() {
            decodedModel = res;
          });
        } catch (e) {
          String msg = Utils.getErrorMessage(e);
          EasyLoading.showError(msg);
        }
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    receiveTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: Container(),
          title: const Text('Receive Ecash'),
        ),
        body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
            child: Column(children: [
              Form(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Expanded(
                    child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: TextField(
                        controller: receiveTextController,
                        textInputAction: TextInputAction.done,
                        autofocus: true,
                        maxLines: 5,
                        minLines: 1,
                        decoration: InputDecoration(
                            labelText: 'Paste Cashu Token',
                            hintText: 'Paste Cashu Token',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.paste),
                              onPressed: () async {
                                final clipboardData =
                                    await Clipboard.getData('text/plain');
                                if (clipboardData != null) {
                                  final pastedText = clipboardData.text;
                                  if (pastedText != null && pastedText != '') {
                                    receiveTextController.text = pastedText;
                                  }
                                }
                              },
                            )),
                      ),
                    ),
                    if (decodedModel != null)
                      ListTile(
                        title: Text(
                            '+${decodedModel?.amount} ${decodedModel!.unit?.toUpperCase() ?? EcashTokenSymbol.sat.name}'),
                        subtitle: Text(decodedModel!.mint),
                      ),
                    const SizedBox(
                      height: 30,
                    ),
                    OutlinedButton.icon(
                        onPressed: () async {
                          String? result =
                              await QrScanService.instance.handleQRScan();
                          if (result != null) {
                            QrScanService.instance.processQRResult(result);
                          }
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan'))
                  ],
                )),
              ),
              FilledButton(
                style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(
                        const Size(double.infinity, 44))),
                child: const Text('Receive'),
                onPressed: () async {
                  String encodedToken = receiveTextController.text.trim();
                  if (encodedToken.isEmpty) {
                    EasyLoading.showToast('Please input token');
                    return;
                  }
                  try {
                    await CashuUtil.handleReceiveToken(token: encodedToken);
                    receiveTextController.clear();
                    controller.requestPageRefresh();
                    setState(() {
                      decodedModel = null;
                    });
                    // Get.back();
                  } catch (e, s) {
                    String msg = Utils.getErrorMessage(e);
                    EasyLoading.showToast(msg);
                    logger.e('Receive token failed', error: e, stackTrace: s);
                  }
                },
              )
            ])));
  }
}
