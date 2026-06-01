import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:keychat/constants/legal_links.dart';
import 'package:keychat/service/storage.dart';

class LegalConsentService {
  LegalConsentService._();

  static bool shouldRequestConsent({required bool hasIdentity}) {
    if (hasIdentity) return false;
    final acceptedVersion = Storage.getIntOrZero(
      StorageKeyString.acceptedLegalVersion,
    );
    return acceptedVersion < LegalLinks.consentVersion;
  }

  static Future<bool> canContinue({
    required bool hasIdentity,
    required bool acceptedLegal,
  }) async {
    if (!shouldRequestConsent(hasIdentity: hasIdentity) || acceptedLegal) {
      return true;
    }
    await HapticFeedback.mediumImpact();
    await EasyLoading.showToast(
      'Please agree to the Terms & Conditions and Privacy Policy first.',
    );
    return false;
  }

  static Future<void> saveAcceptedVersionIfNeeded({
    required bool hasIdentity,
  }) async {
    if (!shouldRequestConsent(hasIdentity: hasIdentity)) return;
    await Storage.setInt(
      StorageKeyString.acceptedLegalVersion,
      LegalLinks.consentVersion,
    );
    await Storage.setInt(
      StorageKeyString.acceptedLegalAt,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
