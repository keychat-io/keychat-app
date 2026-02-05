import 'package:keychat_ecash/lnd/lnd_connection_info.dart';
import 'package:keychat_ecash/lnd/lnd_rest_client.dart';

/// Runtime LND connection state with cached data.
class ActiveLndConnection {
  ActiveLndConnection({
    required this.info,
    required this.client,
    this.balance,
    this.nodeInfo,
  });

  /// Connection configuration
  LndConnectionInfo info;

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
