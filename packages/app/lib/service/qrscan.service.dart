import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/page/chat/create_contact_page.dart';
import 'package:app/page/components.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:bip21_uri/bip21_uri.dart' show bip21;
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

    if (result == null || result.isEmpty || !autoProcess) return result;
    debugPrint("Barcode detected: $result");

    try {
      await processQRResult(result);
    } catch (e) {
      logger.e('Failed to process QR result: $e');
      handleText(result);
    }
    return result;
  }

  Future processQRResult(String str) async {
    final trimmedStr = str.trim();

    // Handle URLs first
    if (_isUrl(trimmedStr)) {
      return handleUrl(trimmedStr);
    }

    // Handle Keychat app links
    if (trimmedStr.startsWith('${KeychatGlobal.mainWebsite}/u/')) {
      return _handleKeychatAppLink(trimmedStr);
    }

    final ecashController = Get.find<EcashController>();

    // Handle Ecash tokens
    if (trimmedStr.startsWith('cashu')) {
      return ecashController.proccessCashuString(trimmedStr);
    }

    // Handle Lightning invoices and related formats
    if (_isLightningInvoice(trimmedStr)) {
      final cleanInvoice = trimmedStr.startsWith('lightning:')
          ? trimmedStr.replaceFirst('lightning:', '')
          : trimmedStr;
      return ecashController.proccessPayLightningBill(cleanInvoice);
    }

    // Handle LNURL and email addresses
    if (trimmedStr.toUpperCase().startsWith('LNURL') || isEmail(trimmedStr)) {
      showModalBottomSheetWidget(
          Get.context!, '', PayInvoicePage(invoce: trimmedStr),
          showAppBar: false);
      return;
    }

    // Handle Bitcoin URIs
    if (trimmedStr.startsWith('bitcoin:')) {
      return handleBitcoinUri(trimmedStr, ecashController);
    }

    // Handle Nostr public keys
    if (_isNostrPubkey(trimmedStr)) {
      Get.bottomSheet(AddtoContactsPage(trimmedStr),
          isScrollControlled: true, ignoreSafeArea: false);
      return;
    }

    // Handle Base64 encoded user data
    if (isBase64(trimmedStr)) {
      return _handleBase64UserData(trimmedStr);
    }
  }

  bool _isUrl(String str) {
    return str.startsWith('http://') || str.startsWith('https://');
  }

  bool _isLightningInvoice(String str) {
    final upperStr = str.toUpperCase();
    return str.startsWith('lightning:') ||
        upperStr.startsWith('LNBC') ||
        upperStr.startsWith('LN01');
  }

  bool _isNostrPubkey(String str) {
    return str.startsWith('npub') || str.length == 64;
  }

  Future<void> _handleKeychatAppLink(String str) async {
    try {
      final uri = Uri.tryParse(str);
      if (uri != null) {
        Get.find<HomeController>().handleAppLink(uri);
        return;
      }
    } catch (e) {
      logger.e('Failed to handle Keychat app link: $e');
    }
    return handleText(str);
  }

  Future<void> handleBitcoinUri(
      String str, EcashController ecashController) async {
    try {
      final decoded = bip21.decode(str);
      final lightningInvoice = decoded.lightningInvoice;
      if (lightningInvoice != null && lightningInvoice.isNotEmpty) {
        await ecashController.proccessPayLightningBill(lightningInvoice);
        return;
      }
    } catch (e) {
      logger.e('Failed to decode Bitcoin URI: $e');
    }
    return handleText(str);
  }

  Future<void> _handleBase64UserData(String str) async {
    try {
      final model = QRUserModel.fromShortString(str);
      await RoomUtil.processUserQRCode(model);
    } catch (e) {
      logger.e('Failed to process Base64 user data: $e');
      return handleText(str);
    }
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
