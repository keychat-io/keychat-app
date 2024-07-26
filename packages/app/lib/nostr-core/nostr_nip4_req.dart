import 'package:app/constants.dart';
import 'package:app/nostr-core/filter.dart';
import 'package:app/nostr-core/request.dart';

/// Used to request events and subscribe to new updates.
class NostrNip4Req {
  late String reqId;
  List<String> pubkeys = [];
  late DateTime since;
  int? limit;
  List<int> kinds = [EventKinds.encryptedDirectMessage];

  NostrNip4Req(
      {required this.reqId,
      required this.pubkeys,
      required this.since,
      this.kinds = const [EventKinds.encryptedDirectMessage],
      this.limit});
  @override
  String toString() {
    return Request(reqId, [
      Filter(
        kinds: kinds,
        p: pubkeys,
        limit: limit,
        since: since.millisecondsSinceEpoch ~/ 1000,
      )
    ]).serialize();
  }

  /// subscription_id is a random string that should be used to represent a subscription.
  // late String subscriptionId;
}
