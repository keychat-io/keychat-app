import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/keychat/qrcode_user_model.dart';

void main() {
  group('QRUserModel.fromShortString backward compat', () {
    // Real-world QR code data encoded with the OLD field order.
    // Validates that fromShortString correctly parses positional data
    // regardless of field naming changes.
    const realQrData =
        'H4sIAAAAAAAAEx2SybEYIQxEc/nnOUhCC4rDEaAtAudf1veJGjQ03a/5+fP+/nzfmLEjPZbwLg9prLgghFF6n53X4eYIxXytK8XhBstjxOabH0hW+is87onxSNGa0WSH/tDdymTOHXIwHbsY+7dfjcJEZIEvGJOnqBCQDB5JPLM3FoEyg90WwoGW01AOapyU+VZezzn8IQMT3ZUCaVY1UWFivNCaDh3lcwbo3scPRGgQDOPk6b1ld45qE+4KG8hafZFAr5b02k5JFcvgUAG/IYibbxUc7z38ZGxE3txN9qx+yU27UP8acFhSVGTLyQtVaZry8oqO4DmlEQNhJdvCsasfMf83YLRxAAvO7Zdk2FZrGW+AaoWSmh3eBMgHCqirNHdfNpZuCwRk+e2Ke4blmsu3BfoSlncS1lstRRHbWe40jM6Lvvv5LPdJaIMT+rDmMbwdh8xbqccvbiEHn5dnam6gaKAB34q39cMOB9S7Z+T1wvMlN/wPhAltpHYCAAA=';

    test('parses all fields from real QR data', () {
      final model = QRUserModel.fromShortString(realQrData);

      expect(model.name, isNotEmpty);
      expect(model.nostrIdentityKey, isNotEmpty);
      expect(model.signalIdentityKey, isNotEmpty);
      expect(model.receiveAddress, isNotEmpty);
      expect(model.signalSignedPrekeyId, isA<int>());
      expect(model.signalSignedPrekey, isNotEmpty);
      expect(model.signalSignedPrekeySignature, isNotEmpty);
      expect(model.signalOneTimePrekeyId, isA<int>());
      expect(model.signalOneTimePrekey, isNotEmpty);
      expect(model.time, greaterThan(0));
      expect(model.globalSign, isNotEmpty);
    });

    test('nostrIdentityKey is 64-char hex', () {
      final model = QRUserModel.fromShortString(realQrData);
      expect(model.nostrIdentityKey.length, equals(64));
      expect(model.nostrIdentityKey, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('signalIdentityKey starts with 05 prefix (33 bytes)', () {
      final model = QRUserModel.fromShortString(realQrData);
      expect(model.signalIdentityKey, startsWith('05'));
      expect(model.signalIdentityKey.length, equals(66));
    });

    test('roundtrip: fromShortString -> toShortStringForQrcode -> fromShortString', () {
      final original = QRUserModel.fromShortString(realQrData);
      final reEncoded = original.toShortStringForQrcode();
      final restored = QRUserModel.fromShortString(reEncoded);

      expect(restored.name, equals(original.name));
      expect(restored.nostrIdentityKey, equals(original.nostrIdentityKey));
      expect(restored.signalIdentityKey, equals(original.signalIdentityKey));
      expect(restored.receiveAddress, equals(original.receiveAddress));
      expect(restored.signalSignedPrekeyId,
          equals(original.signalSignedPrekeyId));
      expect(restored.time, equals(original.time));
      expect(restored.globalSign, equals(original.globalSign));
    });
  });
}
