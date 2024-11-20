import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keychat_rust_ffi_plugin/index.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  test('Can call rust function', () async {
    var a = await rust_nostr.generateSecp256K1();
    print(a.prikey);
    expect(a.pubkey.length, 64);
  });
}
