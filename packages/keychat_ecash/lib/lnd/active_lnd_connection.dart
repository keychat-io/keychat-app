import 'package:keychat_ecash/lnd/lnd_connection_info.dart';
import 'package:keychat_ecash/lnd/lnd_rest_client.dart';

/// Runtime LND connection state with cached data.
class ActiveLndConnection {
  ActiveLndConnection({
    required this.info,
    required this.client,
    required this.identifier,
    this.walletConnectionId,
    this.balance,
    this.nodeInfo,
  });

  /// Connection configuration
  LndConnectionInfo info;

  /// Non-secret identifier for this connection (host:port).
  final String identifier;

  /// Isar record ID for storage operations (update, delete).
  int? walletConnectionId;

  /// REST API client
  final LndRestClient client;

  /// Cached channel balance
  LndChannelBalance? balance;

  /// Cached node information
  LndGetInfoResponse? nodeInfo;

  /// Close the client connection
  void close() {
    client.close();
  }
}
