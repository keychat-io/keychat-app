import 'package:ndk/ndk.dart';
import 'package:keychat_nwc/nwc_connection_info.dart';

class ActiveNwcConnection {
  ActiveNwcConnection({
    required this.info,
    required this.connection,
    this.balance,
    this.transactions,
  });
  NwcConnectionInfo info;
  final NwcConnection connection;
  GetBalanceResponse? balance;
  ListTransactionsResponse? transactions;
}
