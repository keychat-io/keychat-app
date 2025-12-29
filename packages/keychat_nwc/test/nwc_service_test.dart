import 'package:flutter_test/flutter_test.dart';
import 'package:keychat_nwc/nwc.service.dart';
import 'package:keychat_nwc/nwc_connection_storage.dart';
import 'package:keychat_nwc/nwc_connection_info.dart';
import 'package:ndk/ndk.dart';

class MockEventVerifier implements EventVerifier {
  @override
  Future<bool> verify(Nip01Event event) async {
    return true;
  }
}

class FakeNwcConnectionStorage implements NwcConnectionStorage {
  final Map<String, NwcConnectionInfo> _memory = {};

  @override
  Future<List<NwcConnectionInfo>> getAll() async {
    return _memory.values.toList();
  }

  @override
  Future<void> save(List<NwcConnectionInfo> list) async {
    // no-op or implemented if needed, but here we just need in-memory update for add/delete
  }

  @override
  Future<void> add(NwcConnectionInfo info) async {
    _memory[info.uri] = info;
  }

  @override
  Future<void> update(NwcConnectionInfo info) async {
    _memory[info.uri] = info;
  }

  @override
  Future<void> delete(String uri) async {
    _memory.remove(uri);
  }
}

void main() {
  test('NwcService connect and getBalance', () async {
    const nwcUri =
        'nostr+walletconnect://190010af50bd27e99550d1bc84de304e8eb28a3628016cf1d5a884d559783bd4?relay=wss://relay.damus.io&relay=wss://nos.lol&secret=c8ad0a6e313132d322016bb2f38e7a727d32c6e86afc5a7444094678270c23fe';

    final service = NwcService.instance;
    service.storage = FakeNwcConnectionStorage();

    print('Initializing NWC Service...');
    // We need to initialize the service first to setup NDK
    await service.init(eventVerifier: MockEventVerifier());

    // We should clear storage before test ideally, but assuming fresh or compatible
    // For test isolation, we might want to mock storage but here we are doing integration test style
    // Let's just try to add. If it exists, add might throw or we should use logic to check.
    // However, existing test used real network so we will continue that.

    // Since add persists, running this test multiple times might fail if we don't clean up or check existence.
    // Logic in add checks for active connection.
    try {
      print('Adding connection...');
      await service.add(nwcUri);
    } catch (e) {
      // If already active, that's fine for this test run context, unless we want strict isolation
      print('Connection might already exist: $e');
    }

    print('Connected.');

    print('Getting balance...');
    final balance = await service.getBalance(nwcUri);
    if (balance != null) {
      print(
        'Balance Response: ${balance.balanceSats} ,${balance.maxAmount}, ${balance.budgetRenewal}',
      );
    }

    // Simple assertion to ensure we got a response
    expect(balance, isNotNull);
  });
}
