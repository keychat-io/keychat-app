import 'dart:async';

import 'package:keychat/service/qrscan.service.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

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
  final RxBool isLoading = false.obs;

  @override
  void initState() {
    receiveTextController = TextEditingController();
    receiveTextController.addListener(() async {
      final text = receiveTextController.text.trim();
      if (text.isNotEmpty) {
        try {
          final res = await rust_cashu.decodeToken(encodedToken: text);

          setState(() {
            decodedModel = res;
          });
        } catch (e) {
          final msg = Utils.getErrorMessage(e);
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
                icon: const Icon(CupertinoIcons.qrcode_viewfinder),
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
          child: Column(
            children: [
              Expanded(
                child: Form(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                final clipboardData = await Clipboard.getData(
                                  'text/plain',
                                );
                                if (clipboardData != null) {
                                  final pastedText = clipboardData.text;
                                  if (pastedText != null && pastedText != '') {
                                    receiveTextController.text = pastedText;
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      if (decodedModel != null)
                        ListTile(
                          title: Text(
                            '+${decodedModel?.amount} ${decodedModel!.unit}',
                          ),
                          subtitle: Text(decodedModel!.mint),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: GetPlatform.isDesktop ? 200 : double.infinity,
                height: 44,
                child: Obx(
                  () => FilledButton(
                    onPressed: isLoading.value
                        ? null
                        : () async {
                            if (isLoading.value) return;

                            try {
                              isLoading.value = true;
                              if (GetPlatform.isMobile) {
                                HapticFeedback.lightImpact();
                              }
                              final encodedToken =
                                  receiveTextController.text.trim();
                              if (encodedToken.isEmpty) {
                                EasyLoading.showToast('Please input token');
                                return;
                              }
                              await EcashUtils.handleReceiveToken(
                                token: encodedToken,
                                retry: true,
                              );
                              receiveTextController.clear();
                              unawaited(controller.requestPageRefresh());
                              setState(() {
                                decodedModel = null;
                              });
                            } catch (e, s) {
                              await EcashUtils.ecashErrorHandle(e, s);
                            } finally {
                              isLoading.value = false;
                            }
                          },
                    child: isLoading.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Receive'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
