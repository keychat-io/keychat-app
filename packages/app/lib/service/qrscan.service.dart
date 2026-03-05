import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/page/browser/MultiWebviewController.dart';
import 'package:keychat/page/chat/create_contact_page.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:bip21_uri/bip21_uri.dart' show bip21;
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service that opens the QR-code scanner and dispatches the scanned result
/// to the appropriate handler based on content type.
///
/// Supported formats: URLs, Keychat app links, Cashu tokens, Lightning invoices,
/// LNURL, Bitcoin URIs, Nostr pubkeys (npub/hex), NWC URIs, and base64 QR profiles.
class QrScanService {
  // Avoid self instance
  QrScanService._();
  static QrScanService? _instance;
  static QrScanService get instance => _instance ??= QrScanService._();

  /// Opens the QR-code scanner and returns the raw scanned string.
  ///
  /// Only available on mobile and macOS.  Requests camera permission on mobile.
  /// If [autoProcess] is true, automatically dispatches the result to the matching
  /// handler (e.g. opens a contact page, processes a cashu token, etc.).
  /// Returns null if the scan was cancelled or permission was denied.
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
    logger.d('Barcode detected: $result');
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

  /// Decodes a BIP-21 Bitcoin URI and extracts an embedded Lightning invoice if present.
  ///
  /// Falls back to [handleText] if the URI cannot be decoded or has no invoice.
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

  /// Presents a dialog offering to copy or open [url] in the in-app browser.
  ///
  /// Keychat app links (mainWebsite/u/) are handled directly without a dialog.
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

  /// Presents a dialog displaying [str] with options to copy or dismiss.
  ///
  /// Used as a fallback when the scanned content does not match any known format.
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
