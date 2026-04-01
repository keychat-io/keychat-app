import 'package:keychat/constants.dart';
import 'package:keychat/nostr-core/filter.dart';
import 'package:keychat/nostr-core/request.dart';

/// Model for building a Nostr REQ subscription request.
///
/// Wraps [Filter] and [Request] construction for subscribing to events
/// filtered by pubkeys, authors, kinds, and time window.
class NostrReqModel {
  /// Creates a new REQ model.
  ///
  /// [reqId] is the subscription identifier (should be unique per relay).
  /// [since] sets the minimum event timestamp for the filter.
  /// [kinds] defaults to NIP-04 encrypted direct messages.
  NostrReqModel({
    required this.reqId,
    required this.since,
    this.pubkeys,
    this.authors,
    this.kinds = const [EventKinds.nip04],
    this.limit,
  });

  /// Unique subscription identifier sent to the relay.
  late String reqId;

  /// Filter by recipient pubkeys (`#p` tag).
  List<String>? pubkeys;

  /// Filter by event author pubkeys.
  List<String>? authors;

  /// Earliest event timestamp (inclusive) for the subscription.
  late DateTime since;

  /// Maximum number of historical events to return per relay.
  int? limit;

  /// Event kinds to subscribe to.
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
