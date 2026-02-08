import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/nostr-core/nostr_nip4_req.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat_ecash/nwc/nwc_models.dart';
import 'package:keychat_ecash/nwc/nwc_request_manager.dart';
import 'package:keychat_ecash/nwc/nwc_uri_parser.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

/// NWC Client for communicating with a Nostr Wallet Connect server.
///
/// Uses WebsocketService for relay connections and Rust FFI for cryptography.
class NwcClient {
  /// Creates a new NwcClient with the given connection parameters.
  NwcClient({
    required this.params,
    required this.clientPubkey,
    WebsocketService? websocketService,
  }) : _websocketService = websocketService ?? Get.find<WebsocketService>();

  /// Creates a new NwcClient from a NWC URI string.
  static Future<NwcClient> fromUri(String uri) async {
    final params = NwcUriParser.parse(uri);

    // Derive client pubkey from secret
    final clientPubkey = rust_nostr.getHexPubkeyByPrikey(
      prikey: params.secret,
    );

    return NwcClient(
      params: params,
      clientPubkey: clientPubkey,
    );
  }

  /// The parsed connection parameters.
  final NwcConnectionParams params;

  /// The client's public key (derived from secret).
  final String clientPubkey;

  /// The websocket service for relay communication.
  final WebsocketService _websocketService;

  /// The subscription ID for response events.
  String? _subscriptionId;

  /// Whether the client is subscribed.
  bool get isSubscribed => _subscriptionId != null;

  /// The wallet's public key.
  String get walletPubkey => params.walletPubkey;

  /// The client's private key (secret).
  String get _secret => params.secret;

  /// The relay URLs.
  List<String> get relays => params.relays;

  /// Ensures all NWC relays are added to the relay pool and connected.
  ///
  /// Delegates to [WebsocketService.ensureRelaysConnected].
  Future<List<String>> ensureRelaysConnected() async {
    return _websocketService.ensureRelaysConnected(params.relays);
  }

  /// Subscribes to NWC response events (kind 23195).
  ///
  /// Ensures relays are connected before subscribing.
  Future<void> subscribe() async {
    if (_subscriptionId != null) return;

    await ensureRelaysConnected();

    _subscriptionId = 'nwc:${generate64RandomHexChars(16)}';
    final pubkey = rust_nostr.getHexPubkeyByPrikey(
      prikey: params.secret,
    );
    final req = NostrReqModel(
      reqId: _subscriptionId!,
      kinds: [NwcEventKinds.response],
      pubkeys: [pubkey],
      since: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    _websocketService.sendReq(
      req,
      relays: params.relays,
      callback: (String relay) {
        logger.d('NWC subscribed to relay: $relay');
      },
    );
    logger.i(
      'NWC client connected for $walletPubkey, subscriptionId: $_subscriptionId-',
    );
  }

  /// Re-subscribes on a specific relay after it reconnects.
  ///
  /// Only acts if this client uses the given [relayUrl].
  void resubscribeOnRelay(String relayUrl) {
    if (!params.relays.contains(relayUrl)) return;

    // Reset subscription so subscribe() creates a fresh one
    _subscriptionId = null;
    subscribe();
  }

  /// Closes the subscription and cleans up resources.
  void close() {
    if (_subscriptionId != null) {
      // Send CLOSE message to relays
      final closeMsg = '["CLOSE","$_subscriptionId"]';
      try {
        _websocketService.sendReqToRelays(closeMsg, params.relays);
      } catch (e) {
        logger.e('Error closing NWC subscription', error: e);
      }
      _subscriptionId = null;
    }
  }

  /// Sends a request to the wallet and waits for a response.
  ///
  /// Ensures relays are connected, then subscribes if needed, encrypts the
  /// request, and broadcasts to all NWC relays.
  Future<NwcResponse> sendRequest(NwcRequest request) async {
    // Ensure relays are connected and we're subscribed
    final connectedRelays = await ensureRelaysConnected();
    if (connectedRelays.isEmpty) {
      throw Exception('No NWC relays connected for $walletPubkey');
    }
    if (!isSubscribed) {
      await subscribe();
    }
    logger.d('Sending NWC request: ${jsonEncode(request.toJson())}');
    // Encrypt the request content
    final requestJson = jsonEncode(request.toJson());
    final encryptedContent = await rust_nostr.encrypt(
      senderKeys: _secret,
      receiverPubkey: walletPubkey,
      content: requestJson,
    );

    // Create and sign the event
    final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tags = [
      ['p', walletPubkey],
    ];

    final signedEvent = await rust_nostr.signEvent(
      senderKeys: _secret,
      content: encryptedContent,
      createdAt: BigInt.from(createdAt),
      kind: NwcEventKinds.request,
      tags: tags,
    );

    // Parse to get event ID for request tracking
    final eventJson = jsonDecode(signedEvent) as Map<String, dynamic>;
    final eventId = eventJson['id'] as String;

    // Register the pending request
    final responseFuture = NwcRequestManager.instance.registerRequest(eventId);

    // Send the event to relays
    final eventMessage = '["EVENT",$signedEvent]';
    try {
      _websocketService.sendReqToRelays(eventMessage, params.relays);
    } catch (e) {
      NwcRequestManager.instance.completeRequestWithError(eventId, e);
      rethrow;
    }

    // Wait for response
    return responseFuture;
  }

  /// Processes a response event received from a relay.
  ///
  /// Called by the routing layer when kind 23195 events are received.
  Future<void> processResponseEvent(Map<String, dynamic> eventData) async {
    try {
      // Check if this response is for our client
      final pubkey = eventData['pubkey'] as String?;
      if (pubkey != walletPubkey) return;

      // Get the request event ID from tags
      final tags = eventData['tags'] as List<dynamic>?;
      String? requestEventId;
      for (final tag in tags ?? []) {
        if (tag is List && tag.isNotEmpty && tag[0] == 'e') {
          requestEventId = tag[1] as String;
          break;
        }
      }

      if (requestEventId == null) {
        logger.w('NWC response missing event reference tag');
        return;
      }

      // Check if we have a pending request for this
      if (!NwcRequestManager.instance.hasPendingRequest(requestEventId)) {
        logger.d('No pending request for NWC response: $requestEventId');
        return;
      }

      // Decrypt the response content
      final encryptedContent = eventData['content'] as String;
      final decryptedContent = await rust_nostr.decrypt(
        senderKeys: _secret,
        receiverPubkey: walletPubkey,
        content: encryptedContent,
      );

      // Parse the response
      final responseJson = jsonDecode(decryptedContent) as Map<String, dynamic>;
      final response = NwcResponse.fromJson(responseJson);

      // Complete the pending request
      NwcRequestManager.instance.completeRequest(requestEventId, response);
    } catch (e, s) {
      logger.e('Error processing NWC response', error: e, stackTrace: s);
    }
  }

  // ============ API Methods ============

  /// Gets the wallet balance.
  Future<GetBalanceResponse> getBalance() async {
    final request = NwcRequest(
      method: NwcMethod.getBalance.value,
    );

    final response = await sendRequest(request);
    if (response.isError) {
      throw Exception('NWC error: ${response.error}');
    }

    return GetBalanceResponse.fromJson(response.result!);
  }

  /// Gets wallet info.
  Future<GetInfoResponse> getInfo() async {
    final request = NwcRequest(
      method: NwcMethod.getInfo.value,
    );

    final response = await sendRequest(request);
    if (response.isError) {
      throw Exception('NWC error: ${response.error}');
    }

    return GetInfoResponse.fromJson(response.result!);
  }

  /// Lists transactions.
  Future<ListTransactionsResponse> listTransactions({
    int? from,
    int? until,
    int? limit,
    int? offset,
    bool unpaid = true,
  }) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (until != null) params['until'] = until;
    if (limit != null) params['limit'] = limit;
    if (offset != null) params['offset'] = offset;
    params['unpaid'] = unpaid;

    final request = NwcRequest(
      method: NwcMethod.listTransactions.value,
      params: params,
    );

    final response = await sendRequest(request);
    if (response.isError) {
      throw Exception('NWC error: ${response.error}');
    }

    return ListTransactionsResponse.fromJson(response.result!);
  }

  /// Looks up an invoice by invoice string or payment hash.
  Future<LookupInvoiceResponse> lookupInvoice({
    String? invoice,
    String? paymentHash,
  }) async {
    if (invoice == null && paymentHash == null) {
      throw ArgumentError('Either invoice or paymentHash must be provided');
    }

    final params = <String, dynamic>{};
    if (invoice != null) params['invoice'] = invoice;
    if (paymentHash != null) params['payment_hash'] = paymentHash;

    final request = NwcRequest(
      method: NwcMethod.lookupInvoice.value,
      params: params,
    );

    final response = await sendRequest(request);
    if (response.isError) {
      throw Exception('NWC error: ${response.error}');
    }

    return LookupInvoiceResponse.fromJson(response.result!);
  }

  /// Pays a lightning invoice.
  Future<PayInvoiceResponse> payInvoice(String invoice) async {
    final request = NwcRequest(
      method: NwcMethod.payInvoice.value,
      params: {'invoice': invoice},
    );

    final response = await sendRequest(request);
    if (response.isError) {
      throw Exception('NWC error: ${response.error}');
    }

    return PayInvoiceResponse.fromJson(response.result!);
  }

  /// Creates a new invoice.
  Future<MakeInvoiceResponse> makeInvoice({
    required int amountSats,
    String? description,
    String? descriptionHash,
    int? expiry,
  }) async {
    final params = <String, dynamic>{
      'amount': amountSats * 1000, // Convert to msats
    };
    if (description != null) params['description'] = description;
    if (descriptionHash != null) params['description_hash'] = descriptionHash;
    if (expiry != null) params['expiry'] = expiry;

    final request = NwcRequest(
      method: NwcMethod.makeInvoice.value,
      params: params,
    );

    final response = await sendRequest(request);
    if (response.isError) {
      throw Exception('NWC error: ${response.error}');
    }

    return MakeInvoiceResponse.fromJson(response.result!);
  }
}
