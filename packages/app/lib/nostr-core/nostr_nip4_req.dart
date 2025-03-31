import 'package:app/constants.dart';
import 'package:app/nostr-core/filter.dart';
import 'package:app/nostr-core/request.dart';

/// Used to request events and subscribe to new updates.
class NostrReqModel {
  late String reqId;
  List<String>? pubkeys;
  List<String>? authors;
  late DateTime since;
  int? limit;
  List<int> kinds = [EventKinds.nip04];

  NostrReqModel(
      {required this.reqId,
      this.pubkeys,
      this.authors,
      required this.since,
      this.kinds = const [EventKinds.nip04],
      this.limit});

  @override
  String toString() {
    return Request(reqId, [
      Filter(
        kinds: kinds,
        p: pubkeys,
        authors: authors,
        limit: limit,
        since: since.millisecondsSinceEpoch ~/ 1000,
      )
    ]).serialize();
  }
}
