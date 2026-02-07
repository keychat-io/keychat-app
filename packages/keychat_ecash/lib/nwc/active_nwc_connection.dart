import 'package:keychat_ecash/nwc/nwc_client.dart';
import 'package:keychat_ecash/nwc/nwc_connection_info.dart';
import 'package:keychat_ecash/nwc/nwc_models.dart';

/// Represents an active NWC connection with cached data.
class ActiveNwcConnection {
  /// Creates a new ActiveNwcConnection.
  ActiveNwcConnection({
    required this.info,
    required this.client,
    required this.identifier,
    this.walletConnectionId,
    this.balance,
    this.transactions,
  });

  /// The connection info (URI, name, weight).
  NwcConnectionInfo info;

  /// Non-secret identifier for this connection (wallet pubkey).
  final String identifier;

  /// Isar record ID for storage operations (update, delete).
  int? walletConnectionId;

  /// The NWC client for this connection.
  final NwcClient client;

  /// Cached balance response.
  GetBalanceResponse? balance;

  /// Cached transactions response.
  ListTransactionsResponse? transactions;
}
