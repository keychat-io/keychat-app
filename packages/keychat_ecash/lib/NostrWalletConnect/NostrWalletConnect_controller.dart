// implement of https://github.com/nostr-protocol/nips/blob/master/47.md
import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:app/app.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/service/websocket.service.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;

import 'package:app/models/relay.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart';

enum NWCLogMethod { subscribe, receiveEvent, writeEvent, eose, notice, ok }

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
  String localStorageKey = 'nwc:config';
  Rx<Secp256k1SimpleAccount> client =
      Secp256k1SimpleAccount(pubkey: '', prikey: '').obs;
  Rx<Secp256k1SimpleAccount> service =
      Secp256k1SimpleAccount(pubkey: '', prikey: '').obs;
  RxString nwcUri = ''.obs;
  Set<String> subscribeSuccessRelays = {};
  RxSet subscribeAndOnlineRelays = <String>{}.obs;
  RxList<NWCLog> logs = <NWCLog>[].obs;
  String subId13194 = '';
  RxBool featureStatus = false.obs;

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

  Future initWallet({bool loadFromCache = true}) async {
    Map map = await Storage.getLocalStorageMap(localStorageKey);
    logger.d('initWallet: $map');
    if (loadFromCache && map.keys.isNotEmpty) {
      client.value = Secp256k1SimpleAccount(
          pubkey: map['client']['pubkey'], prikey: map['client']['prikey']);
      service.value = Secp256k1SimpleAccount(
          pubkey: map['service']['pubkey'], prikey: map['service']['prikey']);
      featureStatus.value = map['status'] == 1;
      subscribeSuccessRelays.clear();
      subscribeSuccessRelays.addAll(
          (map['enabledRelays'] as List).map((e) => e.toString()).toList());
    } else {
      client.value = await generateSimple();
      service.value = await generateSimple();
      updateLocalStorage();
    }
    initConnectUri();
  }

  initConnectUri() {
    List<String> relays = subscribeSuccessRelays.toList();
    List<String> onlineRelays = websocketService.getOnlineRelayString();
    // Find the intersection of relays and onlineRelays
    List<String> intersectionRelays =
        relays.where((relay) => onlineRelays.contains(relay)).toList();

    subscribeAndOnlineRelays.clear();
    subscribeAndOnlineRelays.addAll(intersectionRelays);
    if (subscribeAndOnlineRelays.isEmpty) {
      nwcUri.value = '';
      return;
    }
    nwcUri.value = nip47EncodeUri(
        pubkey: service.value.pubkey,
        relays: Set.from(subscribeAndOnlineRelays),
        secret: client.value.prikey);
  }

  stopNwc() {
    NostrAPI.instance.okCallback.clear();
    subscribeSuccessRelays.clear();
    proccessedEvents.clear();
    nwcUri.value = '';
    subId13194 = '';
    logs.clear();
  }

  startListening([String? relay]) {
    if (!featureStatus.value) {
      logger.i('Feature:nwc is not enabled');
      return;
    }
    if (service.value.pubkey.isEmpty) return;
    EasyDebounce.debounce('nwc-startListening:$relay', Duration(seconds: 1),
        () {
      loggerNoLine.i('start listening');
      String subId = 'nwc:${generate64RandomHexChars(16)}';
      var req = NostrNip4Req(
          reqId: subId,
          kinds: kinds,
          pubkeys: [service.value.pubkey],
          since: DateTime.now());
      websocketService.sendReq(req, relay: relay, callback: (String relay) {
        if (logs.length > 40) {
          logs.removeRange(0, 30);
        }
        logs.add(NWCLog(
            method: NWCLogMethod.subscribe,
            data: req.toString(),
            relay: relay));
      });
    });
  }

  Future<String> get13194Info() async {
    String content = 'pay_invoice get_balance get_info';
    return await signEvent(
        senderKeys: service.value.prikey,
        content: content,
        createdAt: BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        kind: 13194,
        tags: []);
  }

  Set<String> proccessedEvents = {};
  Future processEvent(Relay relay, NostrEventModel event) async {
    if (!featureStatus.value) {
      logger.i('Feature:nwc is not enabled');
      return;
    }
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
            "alias": "keychat.io",
            "color": "333333",
            "pubkey": service.value.pubkey,
            "network": "mainnet",
            "block_height": 1,
            "block_hash": "",
            "methods": [
              "pay_invoice",
              "get_balance",
              // "make_invoice",
              // "lookup_invoice",
              // "list_transactions",
              "get_info"
            ], // list of supported methods for this connection
            // "notifications": [
            //   "payment_received",
            //   "payment_sent"
            // ],
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
    logs.add(
        NWCLog(method: NWCLogMethod.writeEvent, data: message, relay: relay));
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
  }

  void proccessNotice(Relay relay, List message) {
    loggerNoLine.d('proccessNotice: ${relay.url} : $message');
    logs.add(NWCLog(
        method: NWCLogMethod.notice,
        data: jsonEncode(message),
        relay: relay.url));
  }

  Future setFeatureStatus(bool value) async {
    featureStatus.value = value;
    await updateLocalStorage();
    if (value) {
      await startListening();
      sendMyInfoToRelay();
      return;
    }
    stopNwc();
  }

  Future sendMyInfoToRelay() async {
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
      initConnectUri();
      updateLocalStorage();
    });
    // sync my info
    logs.add(NWCLog(
        method: NWCLogMethod.writeEvent, data: 'info - $info', relay: ''));
    websocketService.sendMessage("[\"EVENT\",$info]");
  }

  Future updateLocalStorage() async {
    await Storage.setString(
        localStorageKey,
        jsonEncode({
          'client': {
            'pubkey': client.value.pubkey,
            'prikey': client.value.prikey
          },
          'service': {
            'pubkey': service.value.pubkey,
            'prikey': service.value.prikey
          },
          'status': featureStatus.value ? 1 : 0,
          'enabledRelays': subscribeSuccessRelays.toList()
        }));
  }
}
