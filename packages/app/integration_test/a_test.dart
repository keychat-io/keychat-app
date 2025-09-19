import 'package:app/constants.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/utils.dart' show generate64RandomHexChars;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test('Can call rust function', () async {
    NostrReqModel req = NostrReqModel(
        reqId: generate64RandomHexChars(16),
        authors: [
          '36b48ff102d063d123f30dcff1e92849af5edf5914540723f87ee896fb0141fa'
        ],
        kinds: [EventKinds.mlsNipKeypackages],
        limit: 1,
        since: DateTime.now().subtract(Duration(days: 365)));
    debugPrint(req.toString());
  });
}
