import 'package:keychat/constants.dart';
import 'package:keychat/nostr-core/filter.dart';
import 'package:keychat/nostr-core/request.dart';

/// Used to request events and subscribe to new updates.
class NostrReqModel {
  NostrReqModel({
    required this.reqId,
    required this.since,
    this.pubkeys,
    this.authors,
    this.kinds = const [EventKinds.nip04],
    this.limit,
  });
  late String reqId;
  List<String>? pubkeys;
  List<String>? authors;
  late DateTime since;
  int? limit;
  List<int> kinds = [EventKinds.nip04];

  @override
  String toString() {
    return Request(reqId, [
      Filter(
        kinds: kinds,
        p: pubkeys,
        authors: authors,
        limit: limit,
        since: since.millisecondsSinceEpoch ~/ 1000,
      ),
    ]).serialize();
  }
}
