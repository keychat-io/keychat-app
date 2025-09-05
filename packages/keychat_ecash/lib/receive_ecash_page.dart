import 'package:app/service/qrscan.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:easy_debounce/easy_throttle.dart';

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
    return SafeArea(
        child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              centerTitle: true,
              leading: Container(),
              title: const Text('Receive Ecash'),
              actions: [
                if (GetPlatform.isMobile || GetPlatform.isMacOS)
                  IconButton(
                      onPressed: () async {
                        QrScanService.instance.handleQRScan();
                      },
                      icon: const Icon(CupertinoIcons.qrcode_viewfinder))
              ],
            ),
            body: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(children: [
                  Expanded(
                    child: Form(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: TextField(
                                controller: receiveTextController,
                                textInputAction: TextInputAction.done,
                                autofocus: true,
                                maxLines: 2,
                                minLines: 1,
                                decoration: InputDecoration(
                                    labelText: 'Paste Cashu Token',
                                    hintText: 'Paste Cashu Token',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.paste),
                                      onPressed: () async {
                                        final clipboardData =
                                            await Clipboard.getData(
                                                'text/plain');
                                        if (clipboardData != null) {
                                          final pastedText = clipboardData.text;
                                          if (pastedText != null &&
                                              pastedText != '') {
                                            receiveTextController.text =
                                                pastedText;
                                          }
                                        }
                                      },
                                    )),
                              ),
                            ),
                            if (decodedModel != null)
                              ListTile(
                                title: Text(
                                    '+${decodedModel?.amount} ${decodedModel!.unit?.toString().toString()}'),
                                subtitle: Text(decodedModel!.mint),
                              ),
                          ],
                        )),
                  ),
                  FilledButton(
                    style: ButtonStyle(
                        minimumSize: WidgetStateProperty.all(
                            const Size(double.infinity, 44))),
                    child: const Text('Receive'),
                    onPressed: () async {
                      EasyThrottle.throttle(
                          'receive_ecash', const Duration(milliseconds: 2000),
                          () async {
                        if (GetPlatform.isMobile) {
                          HapticFeedback.lightImpact();
                        }
                        String encodedToken = receiveTextController.text.trim();
                        if (encodedToken.isEmpty) {
                          EasyLoading.showToast('Please input token');
                          return;
                        }
                        try {
                          await CashuUtil.handleReceiveToken(
                              token: encodedToken, retry: true);
                          receiveTextController.clear();
                          controller.requestPageRefresh();
                          setState(() {
                            decodedModel = null;
                          });
                          // Get.back();
                        } catch (e, s) {
                          String msg = Utils.getErrorMessage(e);
                          EasyLoading.showToast(msg);
                          logger.e('Receive token failed',
                              error: e, stackTrace: s);
                        }
                      });
                    },
                  )
                ]))));
  }
}
