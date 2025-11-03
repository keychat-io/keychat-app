import 'dart:convert' show jsonEncode;

/// Used to stop previous subscriptions.
class Close {
  /// Default constructor
  Close(this.subscriptionId);

  /// Deserialize a nostr close message
  /// - ["CLOSE", subscription_id]
  Close.deserialize(List input) {
    assert(input.length == 2);
    subscriptionId = input[1] as String;
  }

  /// subscription_id is a random string that should be used to represent a subscription.
  late String subscriptionId;

  /// Serialize to nostr close message
  /// - ["CLOSE", subscription_id]
  String serialize() {
    return jsonEncode(['CLOSE', subscriptionId]);
  }
}
