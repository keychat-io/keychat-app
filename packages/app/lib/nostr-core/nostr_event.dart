import 'dart:convert' show jsonEncode;

import 'package:app/constants.dart';
import 'package:app/models/message.dart';

class BIP340VerifyError implements Exception {
  String message = 'BIP340VerifyError';
  // BIP340VerifyError(this.message);
}

/// The only object type that exists is the event, which has the following format on the wire:
///
/// - "id": "32-bytes hex-encoded sha256 of the the serialized event data"
/// - "pubkey": "32-bytes hex-encoded public key of the event creator",
/// - "created_at": unix timestamp in seconds,
/// - "kind": integer,
/// - "tags":
///    ["e", "32-bytes hex of the id of another event", "recommended relay URL"],
///    ["p", "32-bytes hex of the key", "recommended relay URL"]
///  ],
/// - "content": "arbitrary string",
/// - "sig": "64-bytes signature of the sha256 hash of the serialized event data, which is the same as the 'id' field"
class NostrEventModel {
  /// 32-bytes hex-encoded sha256 of the the serialized event data (hex)
  late String id;

  /// 32-bytes hex-encoded public key of the event creator (hex)
  late String pubkey;

  /// unix timestamp in seconds
  late int createdAt;

  /// -  0: set_metadata: the content is set to a stringified JSON object {name: <username>, about: <string>, picture: <url, string>} describing the user who created the event. A relay may delete past set_metadata events once it gets a new one for the same pubkey.
  /// -  1: text_note: the content is set to the text content of a note (anything the user wants to say). Non-plaintext notes should instead use kind 1000-10000 as described in NIP-16.
  /// -  2: recommend_server: the content is set to the URL (e.g., wss://somerelay.com) of a relay the event creator wants to recommend to its followers.
  late int kind;

  /// The tags array can store a tag identifier as the first element of each subarray, plus arbitrary information afterward (always as strings).
  ///
  /// This NIP defines "p" — meaning "pubkey", which points to a pubkey of someone that is referred to in the event —, and "e" — meaning "event", which points to the id of an event this event is quoting, replying to or referring to somehow.
  late List<List<String>> tags;

  /// arbitrary string
  String content = "";

  /// 64-bytes signature of the sha256 hash of the serialized event data, which is the same as the "id" field
  late String sig;

  /// subscription_id is a random string that should be used to represent a subscription.
  String? subscriptionId;

  String? toIdPubkey;

  /// Default constructor
  ///
  /// verify: ensure your event isValid() –> id, signature, timestamp…
  ///
  ///```dart
  /// String id =
  ///     "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49";
  /// String pubKey =
  ///     "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b";
  /// int createdAt = 1672175320;
  /// int kind = 1;
  /// List<List<String>> tags = [];
  /// String content = "Ceci est une analyse du websocket";
  /// String sig =
  ///     "797c47bef50eff748b8af0f38edcb390facf664b2367d72eb71c50b5f37bc83c4ae9cc9007e8489f5f63c66a66e101fd1515d0a846385953f5f837efb9afe885";
  ///
  /// Event event = Event(
  ///   id,
  ///   pubKey,
  ///   createdAt,
  ///   kind,
  ///   tags,
  ///   content,
  ///   sig,
  ///   verify: true,
  ///   subscriptionId: null,
  /// );
  ///```
  NostrEventModel(
    this.id,
    this.pubkey,
    this.createdAt,
    this.kind,
    this.tags,
    this.content,
    this.sig, {
    this.subscriptionId,
    bool verify = true,
  }) {
    pubkey = pubkey.toLowerCase();
  }
  bool get isSignal =>
      kind == EventKinds.encryptedDirectMessage && !content.contains('?iv=');
  bool get isNip4 =>
      kind == EventKinds.encryptedDirectMessage && content.contains('?iv=');
  MessageEncryptType get encryptType => kind == EventKinds.nip17
      ? MessageEncryptType.nip17
      : (isSignal ? MessageEncryptType.signal : MessageEncryptType.nip4);

  /// Partial constructor, you have to fill the fields yourself
  ///
  /// verify: ensure your event isValid() –> id, signature, timestamp…
  ///
  /// ```dart
  /// var partialEvent = Event.partial();
  /// assert(partialEvent.isValid() == false);
  /// partialEvent.createdAt = currentUnixTimestampSeconds();
  /// partialEvent.pubkey =
  ///     "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b";
  /// partialEvent.id = partialEvent.getEventId();
  /// partialEvent.sig = partialEvent.getSignature(
  ///   "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12",
  /// );
  /// assert(partialEvent.isValid() == true);
  /// ```
  factory NostrEventModel.partial({
    id = "",
    pubkey = "",
    createdAt = 0,
    kind = 1,
    tags = const <List<String>>[],
    content = "",
    sig = "",
    subscriptionId,
    bool verify = false,
  }) {
    return NostrEventModel(
      id,
      pubkey,
      createdAt,
      kind,
      tags,
      content,
      sig,
      verify: verify,
    );
  }

  /// Deserialize an event from a JSON
  ///
  /// verify: enable/disable events checks
  ///
  /// This option adds event checks such as id, signature, non-futuristic event: default=True
  ///
  /// Performances could be a reason to disable event checks
  factory NostrEventModel.fromJson(Map<String, dynamic> json,
      {bool verify = true}) {
    var tags = ((json['tags'] ?? []) as List<dynamic>)
        .map((e) => (e as List<dynamic>).map((e) => e as String).toList())
        .toList();
    return NostrEventModel(
      json['id'],
      json['pubkey'],
      json['created_at'],
      json['kind'],
      tags,
      json['content'],
      json['sig'],
      verify: verify,
    )..toIdPubkey = json['toIdPubkey'];
  }

  /// Serialize an event in JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'pubkey': pubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig
      };
  String toJsonString() => jsonEncode(toJson());

  /// Serialize to nostr event message
  /// - ["EVENT", event JSON as defined above]
  /// - ["EVENT", subscription_id, event JSON as defined above]
  String serialize([String type = 'EVENT']) {
    if (subscriptionId != null) {
      return jsonEncode([type, subscriptionId, toJson()]);
    } else {
      return jsonEncode([type, toJson()]);
    }
  }

  /// Deserialize a nostr event message
  /// - A Map: event JSON as defined above
  /// - ["EVENT", event JSON as defined above]
  /// - ["EVENT", subscription_id, event JSON as defined above]
  /// ```dart
  /// Event event = Event.deserialize([
  ///   "EVENT",
  ///   {
  ///     "id": "67bd60e47d7fdddadebff890143167bcd7b5d28b2c3008eae40e0ac5ba0e6b34",
  ///     "kind": 1,
  ///     "pubkey":
  ///         "36685fa5106b1bc03ae7bea82eded855d8f56c41db4c8bdef8099e1e0f2b2afa",
  ///     "created_at": 1674403511,
  ///     "content":
  ///         "Block 773103 was just confirmed. The total value of all the non-coinbase outputs was 61,549,183,849 sats, or \$14,025,828",
  ///     "tags": [],
  ///     "sig":
  ///         "4912a6850a711a876fd2443771f69e094041f7e832df65646a75c2c77989480cce9b41aa5ea3d055c16fe5beb7d11d3d5fa29b4c4046c150b09393c4d3d16eb4"
  ///   }
  /// ]);
  /// ```
  factory NostrEventModel.deserialize(input, {bool verify = true}) {
    Map<String, dynamic> json = {};
    String? subscriptionId;
    if (input.length == 1) {
      json = input as Map<String, dynamic>;
    } else if (input.length == 2) {
      json = input[1] as Map<String, dynamic>;
    } else if (input.length == 3) {
      json = input[2] as Map<String, dynamic>;
      subscriptionId = input[1] as String;
    } else {
      throw Exception('invalid input');
    }

    var tags = (json['tags'] as List<dynamic>)
        .map((e) => (e as List<dynamic>).map((e) => e as String).toList())
        .toList();

    return NostrEventModel(
      json['id'],
      json['pubkey'],
      json['created_at'],
      json['kind'],
      tags,
      json['content'],
      json['sig'],
      subscriptionId: subscriptionId,
      verify: verify,
    );
  }
}
