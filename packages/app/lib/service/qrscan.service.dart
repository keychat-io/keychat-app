import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/page/chat/create_contact_page.dart';
import 'package:app/page/components.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app/models/models.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/utils.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

class QrScanService {
  static QrScanService? _instance;
  // Avoid self instance
  QrScanService._();
  static QrScanService get instance => _instance ??= QrScanService._();

  Future<String?> handleQRScan({bool autoProcess = true}) async {
    if (!(GetPlatform.isMobile || GetPlatform.isMacOS)) {
      EasyLoading.showToast('Not available on this devices');
      return null;
    }
    if (GetPlatform.isMobile) {
      bool isGranted = await Permission.camera.request().isGranted;
      if (!isGranted) {
        EasyLoading.showToast('Camera permission not grant');
        await Future.delayed(const Duration(milliseconds: 1000), () => {});
        openAppSettings();
        return null;
      }
    }
    MobileScannerController mobileScannerController = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
    );
    String? result = await Get.to(() => AiBarcodeScanner(
          controller: mobileScannerController,
          validator: (value) {
            return true;
          },
          onDetect: (BarcodeCapture capture) {
            if (capture.barcodes.isNotEmpty) {
              mobileScannerController.dispose();
              Get.back(result: capture.barcodes.first.rawValue);
            }
          },
        ));
    debugPrint("Barcode detected: $result");

    if (result != null && autoProcess) {
      processQRResult(result);
    }
    return result;
  }

  Future processQRResult(String str) async {
    if (str.startsWith('http://') || str.startsWith('https://')) {
      handleUrl(str);
      return;
    }
    EcashController ecashController = Get.find<EcashController>();
    if (str.startsWith('cashu')) {
      return ecashController.proccessCashuAString(str);
    }
    // lightning invoice
    if (str.startsWith('lightning:')) {
      str = str.replaceFirst('lightning:', '');
      return ecashController.proccessPayLightningBill(str);
    }
    if (str.startsWith('lnbc')) {
      return ecashController.proccessPayLightningBill(str);
    }
    if (str.toUpperCase().startsWith('LNURL') || isEmail(str)) {
      showModalBottomSheetWidget(Get.context!, '', PayInvoicePage(invoce: str),
          showAppBar: false);
      return;
    }
    if (str.startsWith('${KeychatGlobal.mainWebsite}/u/')) {
      try {
        Get.find<HomeController>().handleAppLink(Uri.tryParse(str));
      } catch (e) {
        logger.e('Failed to handle app link: $e');
      }
      return;
    }
    if (str.startsWith('npub') || str.length == 64) {
      Get.bottomSheet(AddtoContactsPage(str),
          isScrollControlled: true, ignoreSafeArea: false);
      return;
    }
    bool isBase = isBase64(str);
    if (isBase) {
      QRUserModel model;
      try {
        model = QRUserModel.fromShortString(str);
      } catch (e) {
        return handleText(str);
      }
      await RoomUtil.processUserQRCode(model);
      return;
    }
    return handleText(str);
  }

  dynamic handleUrl(String url) {
    Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      return handleText(url);
    }
    if (url.startsWith('${KeychatGlobal.mainWebsite}/u/')) {
      Get.find<HomeController>().handleAppLink(uri);
      return;
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
          child: const Text("Copy"),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url.toString()));
            EasyLoading.showSuccess("Copied");
            Get.back();
          },
        ),
        CupertinoDialogAction(
          child: const Text("View in browser"),
          onPressed: () async {
            Get.back();
            if (url.startsWith('https:') || url.startsWith('http:')) {
              Get.find<MultiWebviewController>()
                  .launchWebview(initUrl: url.toString());
              return;
            }
            launchUrl(uri, mode: LaunchMode.platformDefault);
          },
        ),
      ],
    ));
    return;
  }

  void handleText(String str) {
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
}
