import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/page/browser/MultiWebviewController.dart';
import 'package:keychat/page/chat/create_contact_page.dart';
import 'package:keychat/page/components.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:bip21_uri/bip21_uri.dart' show bip21;
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/PayInvoice/PayInvoice_page.dart';
import 'package:keychat_ecash/nwc/nwc_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

class QrScanService {
  // Avoid self instance
  QrScanService._();
  static QrScanService? _instance;
  static QrScanService get instance => _instance ??= QrScanService._();

  Future<String?> handleQRScan({bool autoProcess = false}) async {
    if (!(GetPlatform.isMobile || GetPlatform.isMacOS)) {
      EasyLoading.showToast('Not available on this devices');
      return null;
    }
    if (GetPlatform.isMobile) {
      final isGranted = await Permission.camera.request().isGranted;
      if (!isGranted) {
        EasyLoading.showToast('Camera permission not grant');
        await Future.delayed(const Duration(milliseconds: 1000), () => {});
        openAppSettings();
        return null;
      }
    }
    final mobileScannerController = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
    );
    final result = await Get.to<String>(
      () => AiBarcodeScanner(
        controller: mobileScannerController,
        validator: (value) {
          return true;
        },
        onDetect: (BarcodeCapture capture) async {
          if (capture.barcodes.isNotEmpty) {
            EasyThrottle.throttle(
              'qr_scan',
              const Duration(milliseconds: 500),
              () async {
                await mobileScannerController.dispose();
                Get.back(result: capture.barcodes.first.rawValue);
              },
            );
          }
        },
      ),
    );

    if (result == null || result.isEmpty || !autoProcess) return result;
    debugPrint('Barcode detected: $result');

    try {
      await _processQRResult(result);
    } catch (e) {
      logger.e('Failed to process QR result: $e');
      handleText(result);
    }
    return result;
  }

  Future<void> _processQRResult(String str) async {
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
      ecashController.dialogToPayInvoice(input: cleanInvoice);
      return;
    }

    // Handle LNURL and email addresses
    if (trimmedStr.toUpperCase().startsWith('LNURL') || isEmail(trimmedStr)) {
      await Get.find<EcashController>().dialogToPayInvoice(
        input: trimmedStr,
        isPay: true,
      );
      return;
    }

    // Handle Bitcoin URIs
    if (trimmedStr.startsWith('bitcoin:')) {
      return handleBitcoinUri(trimmedStr, ecashController);
    }

    // Handle Nostr public keys
    if (_isNostrPubkey(trimmedStr)) {
      await Get.bottomSheet<void>(
        AddtoContactsPage(trimmedStr),
        isScrollControlled: true,
        ignoreSafeArea: false,
      );
      return;
    }
    if (str.startsWith(KeychatGlobal.nwcPrefix)) {
      await Utils.getOrPutGetxController(
        create: NwcController.new,
      ).addConnection(str);
      return;
    }

    // Handle Base64 encoded user data
    if (isBase64(trimmedStr)) {
      return _handleBase64UserData(trimmedStr);
    }
    handleText(str);
    return;
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
    String str,
    EcashController ecashController,
  ) async {
    try {
      final decoded = bip21.decode(str);
      final lightningInvoice = decoded.lightningInvoice;
      if (lightningInvoice != null && lightningInvoice.isNotEmpty) {
        await ecashController.dialogToPayInvoice(input: lightningInvoice);
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

    Get.dialog(
      CupertinoAlertDialog(
        title: const Text('Url'),
        content: Text(url),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Get.back<void>();
            },
          ),
          CupertinoDialogAction(
            child: const Text('Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              EasyLoading.showSuccess('Copied');
              Get.back<void>();
            },
          ),
          CupertinoDialogAction(
            child: const Text('View in browser'),
            onPressed: () async {
              Get.back<void>();
              if (url.startsWith('https:') || url.startsWith('http:')) {
                Get.find<MultiWebviewController>().launchWebview(initUrl: url);
                return;
              }
              launchUrl(uri);
            },
          ),
        ],
      ),
    );
    return;
  }

  void handleText(String str) {
    Get.dialog<void>(
      CupertinoAlertDialog(
        title: const Text('Result'),
        content: Text(str),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Get.back<void>();
            },
          ),
          CupertinoDialogAction(
            child: const Text('Copy'),
            onPressed: () {
              Get.back<void>();
              Clipboard.setData(ClipboardData(text: str));
              EasyLoading.showSuccess('Copied');
            },
          ),
        ],
      ),
    );
  }
}
