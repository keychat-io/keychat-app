import 'package:keychat_nwc/nwc_connection_info.dart';
import 'package:ndk/ndk.dart';

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
