// ignore_for_file: unused_local_variable, use_build_context_synchronously

import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/utils.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

import 'package:app/rust_api.dart';
import 'package:flutter/cupertino.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../components.dart';

class QRCodeView extends StatefulWidget {
  const QRCodeView({super.key});

  @override
  State<StatefulWidget> createState() => _QRCodeViewState();
}

class _QRCodeViewState extends State<QRCodeView> {
  MobileScannerController cameraController =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            flexibleSpace: getAppBarFlexibleSpace(),
            centerTitle: true,
            title: Text(
              'Scan',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 18),
            )),
        body: Stack(alignment: Alignment.center, children: [
          MobileScanner(
              // fit: BoxFit.contain,
              controller: cameraController,
              // startDelay: true,
              onDetect: (capture) async {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;
                final barcode = barcodes[0];
                var str = barcode.rawValue!.toString();

                if (str.startsWith('http://') || str.startsWith('https://')) {
                  handleUrl(str);
                  return;
                }
                if (str.startsWith('cashu')) {
                  return _proccessCashuA(str);
                }
                // lighting invoice
                if (str.startsWith('lnbc')) {
                  return _proccessPayLightingBill(str);
                }
                bool isBase = isBase64(str);
                if (isBase) {
                  QRUserModel model;
                  try {
                    model = QRUserModel.fromShortString(str);
                  } catch (e, s) {
                    String msg = Utils.getErrorMessage(e);
                    logger.e('scan error: $msg', stackTrace: s);
                    return handleText(str);
                  }
                  await RoomUtil.processUserQRCode(model);
                  return;
                }
                return handleText(str);
              }),
          if (Get.previousRoute == '/')
            Positioned(
                bottom: 100,
                child: TextButton(
                  onPressed: () async {
                    Identity identity =
                        Get.find<HomeController>().getSelectedIdentity();
                    await showMyQrCode(context, identity, false);
                  },
                  child: const Text('Show My QR Code'),
                ))
        ]));
  }

  handleUrl(String url) {
    late Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      return handleText(url);
    }
    Get.dialog(CupertinoAlertDialog(
      title: const Text("Url"),
      content: Text(url.toString()),
      actions: [
        CupertinoDialogAction(
          child: const Text("Cancel"),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
          child: const Text("View in browser"),
          onPressed: () async {
            Get.back();
            await launchUrl(uri);
          },
        ),
      ],
    ));
    return;
  }

  handleText(String str) {
    Get.dialog(
      CupertinoAlertDialog(
        title: const Text("Result"),
        content: Text(str.toString()),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () {
              Get.back();
            },
          ),
          CupertinoDialogAction(
            child: const Text("Copy"),
            onPressed: () {
              Get.back();
              Clipboard.setData(ClipboardData(text: str.toString()));
              EasyLoading.showSuccess("Copied");
            },
          ),
        ],
      ),
    );
  }

  Future _proccessCashuA(String str) async {
    try {
      CashuInfoModel cashu = await RustAPI.decodeToken(encodedToken: str);
      Get.dialog(CashuReceiveWidget(cashuinfo: cashu));
    } catch (e) {
      return handleText(str);
    }
  }

  _proccessPayLightingBill(String str) async {
    try {
      InvoiceInfo ii = await rust_cashu.decodeInvoice(encodedInvoice: str);
    } catch (e) {
      return handleText(str);
    }
    Get.to(() => PayInvoicePage(str));
  }
}
