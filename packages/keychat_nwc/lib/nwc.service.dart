import 'package:keychat_nwc/active_nwc_connection.dart';
import 'package:keychat_nwc/nwc_connection_info.dart';
import 'package:keychat_nwc/nwc_connection_storage.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart'
    show TransactionStatus;
import 'package:ndk/ndk.dart';
import 'package:ndk_rust_verifier/ndk_rust_verifier.dart';

class NwcService {
  // Avoid self instance
  NwcService._();
  static NwcService? _instance;
  static NwcService get instance => _instance ??= NwcService._();
  late Ndk ndk;

  NwcConnectionStorage _storage = NwcConnectionStorage();
  final Map<String, ActiveNwcConnection> _activeConnections = {};

  /// Inject storage for testing
  set storage(NwcConnectionStorage storage) => _storage = storage;

  List<ActiveNwcConnection> get activeConnections =>
      _activeConnections.values.toList();

  Future<void> init({EventVerifier? eventVerifier}) async {
    ndk = Ndk(
      NdkConfig(
        eventVerifier: eventVerifier ?? RustEventVerifier(),
        cache: MemCacheManager(),
        logLevel: LogLevel.debug,
      ),
    );

    final savedConnections = await _storage.getAll();
    for (final info in savedConnections) {
      await _connectAndAdd(info);
    }
  }

  Future<void> _connectAndAdd(NwcConnectionInfo info) async {
    try {
      final connection = await ndk.nwc.connect(
        info.uri,
      );

      Logger.log.i(
        "waiting for ${connection.isLegacyNotifications() ? "legacy " : ""}notifications for ${info.uri}",
      );
      connection.notificationStream.stream.listen((notification) {
        Logger.log.i(
          'notification ${notification.type} amount: ${notification.amount}',
        );
        // We could also trigger a balance refresh here if needed
      });

      final active = ActiveNwcConnection(info: info, connection: connection);
      _activeConnections[info.uri] = active;
    } catch (e) {
      Logger.log.e('Failed to connect to NWC: ${info.uri} error: $e');
    }
  }

  Future<void> add(String nwcUri, {String? name}) async {
    // Check if already exists
    if (_activeConnections.containsKey(nwcUri)) {
      throw Exception('Connection already active');
    }

    final info = NwcConnectionInfo(uri: nwcUri, name: name);
    await _storage.add(info);
    await _connectAndAdd(info);
  }

  Future<void> remove(String nwcUri) async {
    await _storage.delete(nwcUri);
    _activeConnections.remove(nwcUri);
  }

  Future<GetBalanceResponse?> getBalance(String nwcUri) async {
    final active = _activeConnections[nwcUri];
    if (active == null) {
      throw Exception('NWC Connection not found: $nwcUri');
    }

    if (active.balance != null) {
      return active.balance;
    }

    return refreshBalance(nwcUri);
  }

  Future<GetBalanceResponse> refreshBalance(String nwcUri) async {
    final active = _activeConnections[nwcUri];
    if (active == null) {
      throw Exception('NWC Connection not found: $nwcUri');
    }

    final balance = await ndk.nwc.getBalance(active.connection);
    active.balance = balance;
    return balance;
  }

  Future<void> refreshAllBalances() async {
    for (final uri in _activeConnections.keys) {
      try {
        await refreshBalance(uri);
      } catch (e) {
        Logger.log.e('Failed to refresh balance for $uri: $e');
      }
    }
  }

  Future<PayInvoiceResponse> payInvoice(String nwcUri, String invoice) async {
    final active = _activeConnections[nwcUri];
    if (active == null) {
      throw Exception('NWC Connection not found: $nwcUri');
    }
    return ndk.nwc.payInvoice(active.connection, invoice: invoice);
  }

  Future<ListTransactionsResponse> listTransactions(
    String nwcUri, {
    int? from,
    int? until,
    int? limit,
    int? offset,
    bool unpaid = true,
  }) async {
    final active = _activeConnections[nwcUri];
    if (active == null) {
      throw Exception('NWC Connection not found: $nwcUri');
    }
    final response = await ndk.nwc.listTransactions(
      active.connection,
      from: from,
      until: until,
      limit: limit,
      offset: offset,
      unpaid: unpaid,
    );
    active.transactions = response;
    return response;
  }

  Future<LookupInvoiceResponse?> lookupInvoice(
    String nwcUri, {
    String? invoice,
  }) async {
    final active = _activeConnections[nwcUri];
    if (active == null) {
      throw Exception('NWC Connection not found: $nwcUri');
    }
    return ndk.nwc.lookupInvoice(active.connection, invoice: invoice);
  }

  Future<MakeInvoiceResponse?> makeInvoice(
    String nwcUri, {
    required int amountSats,
    String? description,
    String? descriptionHash,
    int? expiry,
  }) async {
    final active = _activeConnections[nwcUri];
    if (active == null) {
      throw Exception('NWC Connection not found: $nwcUri');
    }
    return ndk.nwc.makeInvoice(
      active.connection,
      amountSats: amountSats,
      description: description,
      descriptionHash: descriptionHash,
      expiry: expiry,
    );
  }

  TransactionStatus getTransactionStatus(TransactionResult transaction) {
    if (transaction.preimage != null && transaction.preimage!.isNotEmpty) {
      return TransactionStatus.success;
    }
    if (transaction.expiresAt != null && transaction.expiresAt! > 0) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        transaction.expiresAt! * 1000,
      );
      if (DateTime.now().isAfter(expiry)) {
        return TransactionStatus.expired;
      }
    }
    return TransactionStatus.pending;
  }
}
