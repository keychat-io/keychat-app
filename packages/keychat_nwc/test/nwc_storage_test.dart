import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keychat_nwc/nwc_connection_info.dart';
import 'package:keychat_nwc/nwc_connection_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Define valid URIs
  const validUri1 =
      'nostr+walletconnect://b889ff5b1513b641e2a139f661a66136637987dc3648de56796eb094b9f074d2?relay=wss://relay.damus.io&secret=123';
  const validUri2 =
      'nostr+walletconnect://a889ff5b1513b641e2a139f661a66136637987dc3648de56796eb094b9f074d2?relay=wss://relay.damus.io&secret=456';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('NwcConnectionInfo', () {
    test('should validate URI on creation', () {
      expect(
        () => NwcConnectionInfo(uri: 'invalid_uri'),
        throwsArgumentError,
      );
      expect(
        () => NwcConnectionInfo(uri: validUri1),
        returnsNormally,
      );
    });

    test('should serialize and deserialize correctly', () {
      final info = NwcConnectionInfo(
        uri: validUri1,
        name: 'My Wallet',
        weight: 10,
      );
      final json = info.toJson();
      final fromJson = NwcConnectionInfo.fromJson(json);
      expect(fromJson, equals(info));
    });
  });

  group('NwcConnectionStorage', () {
    late NwcConnectionStorage storage;

    setUp(() {
      storage = NwcConnectionStorage();
    });

    test('should start empty', () async {
      final list = await storage.getAll();
      expect(list, isEmpty);
    });

    test('should add connection', () async {
      final info = NwcConnectionInfo(uri: validUri1, name: 'Wallet 1');
      await storage.add(info);

      final list = await storage.getAll();
      expect(list, hasLength(1));
      expect(list.first, equals(info));
      expect(list.first.weight, 0); // Default weight
    });

    test('should prevent duplicate URIs', () async {
      final info1 = NwcConnectionInfo(uri: validUri1, name: 'Wallet 1');
      await storage.add(info1);

      final info2 = NwcConnectionInfo(uri: validUri1, name: 'Duplicate');
      expect(() => storage.add(info2), throwsException);
    });

    test('should update connection', () async {
      final info = NwcConnectionInfo(uri: validUri1, name: 'Wallet 1');
      await storage.add(info);

      final updatedInfo =
          NwcConnectionInfo(uri: validUri1, name: 'Updated Wallet', weight: 5);
      await storage.update(updatedInfo);

      final list = await storage.getAll();
      expect(list, hasLength(1));
      expect(list.first.name, 'Updated Wallet');
      expect(list.first.weight, 5);
    });

    test('should delete connection', () async {
      await storage.add(NwcConnectionInfo(uri: validUri1));
      await storage.add(NwcConnectionInfo(uri: validUri2));

      var list = await storage.getAll();
      expect(list, hasLength(2));

      await storage.delete(validUri1);

      list = await storage.getAll();
      expect(list, hasLength(1));
      expect(list.first.uri, validUri2);
    });
  });
}
