import 'dart:convert' show jsonEncode;

import 'package:keychat/nostr-core/filter.dart';

/// Used to request events and subscribe to new updates.
class Request {
  Request(this.subscriptionId, this.filters);

  /// Deserialize a nostr request message
  /// - ["REQ", subscription_id, filter JSON, filter JSON, ...]
  Request.deserialize(List input) {
    assert(input.length >= 3);
    subscriptionId = input[1] as String;
    filters = [];
    for (var i = 2; i < input.length; i++) {
      filters.add(Filter.fromJson(input[i]));
    }
  }

  /// subscription_id is a random string that should be used to represent a subscription.
  late String subscriptionId;

  /// filters is a JSON object that determines what events will be sent in that subscription
  late List<Filter> filters;

  /// Serialize to nostr request message
  /// - ["REQ", subscription_id, filter JSON, filter JSON, ...]
  String serialize() {
    final theFilters = jsonEncode(
      filters.map((item) => item.toJson()).toList(),
    );
    final header = jsonEncode(['REQ', subscriptionId]);
    return '${header.substring(0, header.length - 1)},${theFilters.substring(1, theFilters.length)}';
  }
}
