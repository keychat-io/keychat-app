// implement of https://github.com/nostr-protocol/nips/blob/master/47.md
import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:app/nostr-core/nostr.dart';
import 'package:app/service/websocket.service.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

import 'package:app/models/relay.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart';

enum NWCLogMethod { subscribe, receiveEvent, send, eose, notice, ok }

class NWCLog {
  late DateTime time;
  NWCLogMethod method;
  String data;
  String relay;
  NWCLog({required this.method, required this.data, required this.relay}) {
    time = DateTime.now();
  }
}

class NostrWalletConnectController extends GetxController {
  List<int> kinds = [23194, 23196];
  Rx<Secp256k1SimpleAccount> client =
      Secp256k1SimpleAccount(pubkey: '', prikey: '').obs;
  Rx<Secp256k1SimpleAccount> service =
      Secp256k1SimpleAccount(pubkey: '', prikey: '').obs;
  RxString nwcUri = ''.obs;
  RxSet subscribeSuccessRelays = <String>{}.obs;
  RxList<NWCLog> logs = <NWCLog>[].obs;
  String subId13194 = '';

  late EcashController ecashController;
  late WebsocketService websocketService;

  @override
  void onInit() {
    ecashController = Get.find<EcashController>();
    websocketService = Get.find<WebsocketService>();
    initWallet();
    super.onInit();
  }

  @override
  void dispose() {
    stopNwc();
    super.dispose();
  }

  void initWallet() async {
    client.value = const Secp256k1SimpleAccount(
        pubkey:
            'a2e152d65801377bfb7f7fa70f8d4a0ea7217c9b026bff575a9a22cad38e9ad8',
        prikey:
            '853c5acb0ad42d3fb9393133dbfff4454f93d24882de0c8a54cb07088e333158'); //await generateSimple();
    service.value = const Secp256k1SimpleAccount(
        pubkey:
            '049019177ce49b08c283bfd5ec9eeccbcca7cf08f67058c8064829d3a4dcb5cf',
        prikey:
            '11656bf7381eb113d63b170aae63f00095c349f738f637ba37bb3106c93df34b');

    startListening();
  }

  stopNwc() {
    NostrAPI.instance.okCallback.clear();
    subscribeSuccessRelays.clear();
    nwcUri.value = '';
    subId13194 = '';
    logs.clear();
  }

  startListening() async {
    stopNwc();
    loggerNoLine.i('start listening');
    String subId = 'nwc:${generate64RandomHexChars(16)}';
    var req = NostrNip4Req(
        reqId: subId,
        kinds: kinds,
        pubkeys: [service.value.pubkey],
        since: DateTime.now());
    websocketService.sendReq(req, callback: (String relay) {
      logs.add(NWCLog(
          method: NWCLogMethod.subscribe, data: req.toString(), relay: relay));
    });
  }

  Future<String> get13194Info() async {
    String content =
        'pay_invoice pay_keysend get_balance get_info make_invoice lookup_invoice list_transactions multi_pay_invoice multi_pay_keysend sign_message notifications';
    return await signEvent(
        senderKeys: service.value.prikey,
        content: content,
        createdAt: BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        kind: 13194,
        tags: []);
  }

  Set<String> proccessedEvents = {};
  Future processEvent(Relay relay, NostrEventModel event) async {
    if (proccessedEvents.contains(event.id)) {
      return;
    }
    proccessedEvents.add(event.id);
    String decrypted = await decryptEvent(
        senderKeys: client.value.prikey, json: event.toJsonString());
    logger.d('${event.id}: $decrypted');
    logs.add(NWCLog(
        method: NWCLogMethod.receiveEvent, data: decrypted, relay: relay.url));
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
            "pubkey": service.value.pubkey,
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
        _sendMessage(relay.url, jsonEncode(data), id: event.id);
        break;
      case 'pay_invoice':
        //  {"method":"pay_invoice","params":{"invoice":"lnbc100u1pnu0jprdq8tfshqggnp4q0jpupgrckssvvec508psl9wum6r9psxv4q9cqx7mc8u9sy92sx26pp5vvs2wg2kn45e2kndhvzqvvfpwzcm0ghdyp9xylnlff9frsem2dgqsp5jj2zwws50mwsz4ngmm92huvxuezn0g5cj468syzl4vteskuqexqs9qyysgqcqpcxqyz5vqrzjqw9fu4j39mycmg440ztkraa03u5qhtuc5zfgydsv6ml38qd4azymlapyqqqqqqq2zgqqqqlgqqqq86qqjq89mjun9paqc5jvucz2arnehpqm53qxzasrwu094ex9dsuehjjuzxf8w3g33n2gt3pzndh9uqz30ly0hdmg9n0djzjncpvqy2tkaw3ygq2uhmhe"}
        var params = data['params'];
        if (params == null) return;
        String? invoice = params['invoice'];
        if (invoice == null) return;

        // lightning invoice
        if (invoice.startsWith('lightning:')) {
          invoice = invoice.replaceFirst('lightning:', '');
        }
        if (!invoice.startsWith('lnbc')) return;
        Transaction? tx = await ecashController
            .proccessPayLightningBill(invoice, isPay: true);
        late Map toSendMessage;
        if (tx == null) {
          try {
            rust_cashu.InvoiceInfo ii =
                await rust_cashu.decodeInvoice(encodedInvoice: invoice);

            // Print all fields of the invoice
            loggerNoLine.d('paymentHash: ${ii.hash}');
            loggerNoLine.d('description: ${ii.memo}');
            loggerNoLine.d('expiry: ${ii.expiryTs}');
            loggerNoLine.d('amount: ${ii.amount}');
            loggerNoLine.d('mint: ${ii.mint}');
            toSendMessage = {
              "result_type": "pay_invoice",
              "error": {"code": "PAYMENT_FAILED", "message": "User Cancel"},
            };
          } catch (e) {
            toSendMessage = {
              "result_type": "pay_invoice",
              "error": {
                "code": "PAYMENT_FAILED",
                "message": "Invoice decoded failed"
              },
            };
          }
        } else {
          var lnTx = tx.field0 as LNTransaction;

          if (lnTx.status != TransactionStatus.success) {
            toSendMessage = {
              "result_type": "pay_invoice",
              "error": {"code": "PAYMENT_FAILED", "message": "PAYMENT FAILED"},
            };
          } else {
            toSendMessage = {
              "result_type": "pay_invoice",
              "result": {
                "preimage": lnTx.hash,
                "fees_paid": lnTx.fee?.toInt() ?? 0,
              }
            };
          }
        }
        _sendMessage(relay.url, jsonEncode(toSendMessage), id: event.id);
        break;
      case 'get_balance':
        var data = {
          "result_type": "get_balance",
          "result": {"balance": ecashController.totalSats.value * 1000}
        };
        _sendMessage(relay.url, jsonEncode(data), id: event.id);
        break;
      default:
    }
  }

  Future _sendMessage(String relay, String message, {String? id}) async {
    loggerNoLine.d('send message: $message');
    var encrypted = await encrypt(
        senderKeys: service.value.prikey,
        receiverPubkey: client.value.pubkey,
        content: message);
    List<List<String>> tags = [
      ['p', client.value.pubkey]
    ];
    if (id != null) {
      tags.add(['e', id]);
    }
    var res = await signEvent(
        senderKeys: service.value.prikey,
        content: encrypted,
        createdAt: BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        kind: 23195,
        tags: tags);
    String data = "[\"EVENT\",$res]";
    websocketService.sendMessage(data);
    logs.add(NWCLog(method: NWCLogMethod.send, data: message, relay: relay));
  }

  String nip47EncodeUri({
    required String pubkey,
    required Set<String> relays,
    required String secret,
    String? lud16,
  }) {
    final scheme = 'nostr+walletconnect';

    String uri = '$scheme://$pubkey';

    // Add each relay as a separate parameter
    bool isFirstParam = true;
    for (var relay in relays) {
      uri += isFirstParam ? '?' : '&';
      uri += 'relay=${Uri.encodeComponent(relay.toString())}';
      isFirstParam = false;
    }

    // Add secret parameter
    uri += '&secret=$secret';

    // Add lud16 parameter if provided
    if (lud16 != null && lud16.isNotEmpty) {
      uri += '&lud16=${Uri.encodeComponent(lud16)}';
    }

    return uri;
  }

  void proccessEOSE(Relay relay, List res) async {
    loggerNoLine.d('proccessEOSE: ${relay.url} : $res');
    logs.add(NWCLog(
        method: NWCLogMethod.eose, data: jsonEncode(res), relay: relay.url));
    String info = await get13194Info();
    String subId = jsonDecode(info)['id'];
    // success callback
    NostrAPI.instance.setOKCallback(subId, (
        {required String relay,
        required String eventId,
        required bool status,
        String? errorMessage}) {
      logger.d('setOKCallback: $relay - $status - $errorMessage');
      logs.add(NWCLog(
          method: NWCLogMethod.ok,
          data: '$status - $errorMessage',
          relay: relay));
      if (status) {
        subscribeSuccessRelays.add(relay);
      } else {
        subscribeSuccessRelays.remove(relay);
      }
      if (subscribeSuccessRelays.isNotEmpty) {
        nwcUri.value = nip47EncodeUri(
            pubkey: service.value.pubkey,
            relays: subscribeSuccessRelays as Set<String>,
            secret: client.value.prikey);
      } else {
        nwcUri.value = '';
      }
      loggerNoLine.d('nwcUri: ${nwcUri.value}');
    });
    websocketService.sendMessage("[\"EVENT\",$info]");
  }

  void proccessNotice(Relay relay, List message) {
    loggerNoLine.d('proccessNotice: ${relay.url} : $message');
    logs.add(NWCLog(
        method: NWCLogMethod.notice,
        data: jsonEncode(message),
        relay: relay.url));
  }
}
