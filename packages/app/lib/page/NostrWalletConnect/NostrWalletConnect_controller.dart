import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:app/models/relay.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart';
import 'package:web_socket_client/web_socket_client.dart';

//  ["REQ","sub:1",{"kinds":[13194],"limit":1,"authors":["049019177ce49b08c283bfd5ec9eeccbcca7cf08f67058c8064829d3a4dcb5cf"]}]
class NostrWalletConnectController extends GetxController {
  late Secp256k1SimpleAccount client;
  late Secp256k1SimpleAccount service;
  RxString nwcUri = ''.obs;
  String defaultRelay = 'wss://relay.8333.space'; //'wss://relay.damus.io';
  List<int> kinds = [23194, 23196];
  RxString socketStatus = 'init'.obs;
  WebSocket? socket;

  @override
  void onInit() {
    initWallet();
    super.onInit();
  }

  @override
  void dispose() {
    socket?.close(1000, 'CLOSE_NORMAL');
    super.dispose();
  }

  getRelayEnableNip47() {}
  void initWallet() async {
    client = const Secp256k1SimpleAccount(
        pubkey:
            'a2e152d65801377bfb7f7fa70f8d4a0ea7217c9b026bff575a9a22cad38e9ad8',
        prikey:
            '853c5acb0ad42d3fb9393133dbfff4454f93d24882de0c8a54cb07088e333158'); //await generateSimple();
    service = const Secp256k1SimpleAccount(
        pubkey:
            '049019177ce49b08c283bfd5ec9eeccbcca7cf08f67058c8064829d3a4dcb5cf',
        prikey:
            '11656bf7381eb113d63b170aae63f00095c349f738f637ba37bb3106c93df34b');
    loggerNoLine.d('client pubkey: ${client.pubkey}');
    loggerNoLine.d('client private: ${client.prikey}');
    loggerNoLine.d('service pubkey: ${service.pubkey}');
    loggerNoLine.d('service private: ${service.prikey}');

    nwcUri.value = await nip47EncodeUri(
        pubkey: service.pubkey, relay: defaultRelay, secret: client.prikey);
    loggerNoLine.d(nwcUri);
    startConnectWebSocket(defaultRelay);
  }

  void startConnectWebSocket(String relay) async {
    loggerNoLine.i('start connect $relay');
    socket = WebSocket(Uri.parse(relay));

    socket!.messages.listen((message) {
      NostrAPI.instance.addNostrEventToQueue(Relay(relay), message);
    }, onDone: () {
      logger.d('websocket onDone');
    }, onError: (e) {
      logger.e('onError ${e.toString()}');
    });
    // connected
    await socket!.connection.firstWhere((state) => state is Connected);
    monitorSocketConnectionStatus();

    // start listen
    String subId = generate64RandomHexChars(16);
    var req = NostrNip4Req(
        reqId: subId,
        kinds: kinds,
        pubkeys: [service.pubkey],
        since: DateTime.now());
    writeToSocket(relay, req.toString());
    sendInfoEvent(relay);
  }

  void monitorSocketConnectionStatus() {
    socket?.connection.listen((state) {
      if (state is Connecting) {
        socketStatus.value = 'connecting';
      } else if (state is Connected) {
        socketStatus.value = 'connected';
      } else if (state is Reconnecting) {
        socketStatus.value = 'reconnecting';
      } else if (state is Disconnected) {
        socketStatus.value = 'disconnected';
        // Optional: Attempt to reconnect after disconnection
        // Future.delayed(Duration(seconds: 5), () => startConnectWebSocket());
      }
      logger.d('Socket status changed: ${socketStatus.value}');
    });
  }

  void reconnect() {
    socket?.close(1000, 'CLOSE_NORMAL');
    startConnectWebSocket(defaultRelay);
  }

  writeToSocket(String relay, String msg) {
    loggerNoLine.d('to-$relay: $msg');
    socket?.send(msg);
  }

  sendInfoEvent(String relay) async {
    String content =
        'pay_invoice pay_keysend get_balance get_info make_invoice lookup_invoice list_transactions multi_pay_invoice multi_pay_keysend sign_message notifications';
    var res = await signEvent(
        senderKeys: service.prikey,
        content: content,
        createdAt: BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        kind: 13194,
        tags: []);
    String data = "[\"EVENT\",$res]";
    writeToSocket(relay, data);
  }

  Set<String> proccessedEvents = {};
  void processEvent(String relay, NostrEventModel event) async {
    if (proccessedEvents.contains(event.id)) {
      return;
    }
    proccessedEvents.add(event.id);
    String decrypted = await decryptEvent(
        senderKeys: client.prikey, json: event.toJsonString());
    logger.d('${event.id}: $decrypted');
    Map data = {};
    try {
      data = jsonDecode(decrypted);
    } catch (e) {
      logger.e('jsonDecode error: $e');
    }
    switch (data['method']) {
      case 'get_info':
        var data = {
          "result_type": "get_info",
          "result": {
            "alias": "keychat",
            "color": "333333",
            "pubkey": service.pubkey,
            "network": "mainnet", // mainnet, testnet, signet, or regtest
            "block_height": 1,
            "block_hash": "",
            "methods": [
              "pay_invoice",
              "get_balance",
              "make_invoice",
              "lookup_invoice",
              "list_transactions",
              "get_info"
            ], // list of supported methods for this connection
            "notifications": [
              "payment_received",
              "payment_sent"
            ], // list of supported notifications for this connection, optional.
          }
        };
        sendMessage(relay, jsonEncode(data), id: event.id);
        break;
      case 'pay_invoice':
        //  {"method":"pay_invoice","params":{"invoice":"lnbc100u1pnu0jprdq8tfshqggnp4q0jpupgrckssvvec508psl9wum6r9psxv4q9cqx7mc8u9sy92sx26pp5vvs2wg2kn45e2kndhvzqvvfpwzcm0ghdyp9xylnlff9frsem2dgqsp5jj2zwws50mwsz4ngmm92huvxuezn0g5cj468syzl4vteskuqexqs9qyysgqcqpcxqyz5vqrzjqw9fu4j39mycmg440ztkraa03u5qhtuc5zfgydsv6ml38qd4azymlapyqqqqqqq2zgqqqqlgqqqq86qqjq89mjun9paqc5jvucz2arnehpqm53qxzasrwu094ex9dsuehjjuzxf8w3g33n2gt3pzndh9uqz30ly0hdmg9n0djzjncpvqy2tkaw3ygq2uhmhe"}
        var params = data['params'];
        if (params == null) return;
        var invoice = params['invoice'];
        if (invoice == null) return;
        EcashController ecashController = Get.find<EcashController>();

        if (invoice.startsWith('cashu')) {
          ecashController.proccessCashuAString(invoice);
          return;
        }
        // lightning invoice
        if (invoice.startsWith('lightning:')) {
          invoice = invoice.replaceFirst('lightning:', '');
          ecashController.proccessPayLightningBill(invoice, pay: true);
          return;
        }
        if (invoice.startsWith('lnbc')) {
          ecashController.proccessPayLightningBill(invoice, pay: true);
          return;
        }
        break;
      default:
    }
  }

  Future sendMessage(String relay, String message, {String? id}) async {
    var encrypted = await encrypt(
        senderKeys: service.prikey,
        receiverPubkey: client.pubkey,
        content: message);
    List<List<String>> tags = [
      ['p', client.pubkey]
    ];
    if (id != null) {
      tags.add(['e', id]);
    }
    var res = await signEvent(
        senderKeys: service.prikey,
        content: encrypted,
        createdAt: BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        kind: 23195,
        tags: tags);
    String data = "[\"EVENT\",$res]";
    writeToSocket(relay, data);
  }

  test() {
    var data = {
      "content":
          "VGNpkVfus1iEFYWuXSll+PlCuJu8ZxU0Rr63LAfJEMdlm+AW6x4l+1S9shGHhIxI?iv=ESTPeNqu4nSuybUUnub+zg==",
      "created_at": 1741140913,
      "id": "b333b78f7e5dd8c02420c6c9aada5a070e8b04dc16e89b81edc2af848dec4a93",
      "kind": 23194,
      "pubkey":
          "a2e152d65801377bfb7f7fa70f8d4a0ea7217c9b026bff575a9a22cad38e9ad8",
      "sig":
          "9fb83fc154634ff75f91e45b1aaeec999faf196a1f58af5bb5c5d67394f3bb8e30bb5f81b2e5f74271f4074435cfa6fcee90dd0236c26eb4c097526e72d32d0e",
      "tags": [
        [
          "p",
          "049019177ce49b08c283bfd5ec9eeccbcca7cf08f67058c8064829d3a4dcb5cf"
        ],
        ["v", "0.0"]
      ]
    };
    var nem = NostrEventModel.fromJson(data);
    processEvent(defaultRelay, nem);
  }

  // 23194
}
