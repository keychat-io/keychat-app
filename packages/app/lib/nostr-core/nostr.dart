import 'dart:collection' show Queue;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:app/controller/world.controller.dart';

import 'package:app/models/models.dart';
import 'package:app/nostr-core/filter.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/nostr-core/relay_event_status.dart';

import 'package:app/nostr-core/request.dart';

import 'package:app/service/identity.service.dart';
import 'package:app/service/kdf_group.service.dart';
import 'package:app/service/nip4Chat.service.dart';
import 'package:app/service/signalChat.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart';
import 'package:keychat_rust_ffi_plugin/index.dart';

import '../constants.dart';
import '../controller/home.controller.dart';
import '../models/db_provider.dart';
import '../service/message.service.dart';
import '../service/contact.service.dart';
import '../service/room.service.dart';
import '../service/storage.dart';
import '../utils.dart' as utils;

typedef OnMessageReceived = void Function(int type, dynamic message);

class NostrAPI {
  static DBProvider dbProvider = DBProvider();
  static RoomService roomService = RoomService();
  Set<String> processedEventIds = {};
  String nip05SubscriptionId = '';
  bool _processingLock = false;
  final nostrEventQueue = Queue<List<dynamic>>();
  static final NostrAPI _instance = NostrAPI._internal();
  NostrAPI._internal();

  factory NostrAPI() => _instance;

  String closeSerialize(String subscriptionId) {
    return jsonEncode(["CLOSE", subscriptionId]);
  }

  Future checkFaildEvent() async {
    await Future.delayed(const Duration(seconds: 6));
    String reqId = utils.generate64RandomHexChars(16);
    List<EventLog> list = await DBProvider().getFaildEventLog();
    if (list.isEmpty) return;
    logger.i('found ${list.length} failed event');
    List<String> eventlogs = list.map((element) {
      return element.eventId;
    }).toList();

    Request requestWithFilter = Request(reqId, [
      Filter(
        kinds: [EventKinds.encryptedDirectMessage],
        e: eventlogs,
        limit: 30,
      )
    ]);
    var req = requestWithFilter.serialize();
    Get.find<WebsocketService>().sendRawReq(req);

    // after 3s. retry
    await Future.delayed(const Duration(seconds: 3));
    List<EventLog> list2 = await DBProvider().getFaildEventLog();
    if (list2.isEmpty) return;
    for (var item in list2) {
      Get.find<WebsocketService>().sendRawReq('["EVENT",${item.snapshot}]');
    }
  }

  logNostrEvent(Relay relay, List list) {
    if (list[0] != 'EVENT') {
      logger.i('${relay.url}: $list');
      return;
    }
  }

  logNostrEventK4(Relay relay, NostrEventModel event) {
    logger.i(
      '''Relay: ${relay.url}: subscribId ${event.id}:
From: ${event.pubkey} 
Tags: ${event.tags}''',
    );
  }

  processWebsocketMessage(Relay relay, dynamic message) async {
    //logger.d('processWebsocketMessage, ${relay.url} $message');
    nostrEventQueue.add([relay, message]);
    if (_processingLock) return;
    return await _processWebsocketMessage2();
  }

  Future _processWebsocketMessage2() async {
    if (nostrEventQueue.isEmpty) {
      _processingLock = false;
      return;
    }
    _processingLock = true;
    List data = nostrEventQueue.removeFirst();
    Relay relay = data[0];
    dynamic message = data[1];
    var res = jsonDecode(message);
    try {
      switch (res[0]) {
        case NostrResKinds.ok:
          loggerNoLine.i('OK: ${relay.url}, $res');
          await _processWriteEventResponse(res, relay);
          break;
        case NostrResKinds.event:
          loggerNoLine.i('receive event: ${relay.url} $message');
          await _processEvent(res, relay, message);
          break;
        case NostrResKinds.eose:
          loggerNoLine.i('EOSE: ${relay.url} ${res[1]}');
          await _proccessEOSE(relay, res);
          break;
        case NostrResKinds.notice:
          String message = res[1];
          if (message == 'could not parse command') {
            message = 'ping respose';
          }
          loggerNoLine.i("Nostr notice: ${relay.url} $message");
          _proccessNotice(relay, res[1]);
          break;
        default:
          logger.i('${relay.url}: $message');
      }
    } finally {
      _processingLock = false;
    }
    await _processWebsocketMessage2();
  }

  _proccessEOSE(Relay relay, List res) async {
    try {
      String key = '${StorageKeyString.lastMessageAt}:${relay.url}';
      int lastMessageAt = await Storage.getIntOrZero(key);
      if (lastMessageAt == 0) return;

      DateTime? messageTime = await MessageService().getLastMessageTime();
      if (messageTime == null) return;
      if (lastMessageAt > (messageTime.millisecondsSinceEpoch ~/ 1000)) {
        return;
      }

      Storage.setInt(key, lastMessageAt + 1);
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  // ignore: unused_element
  _processAUTH(List msg1, Relay relay, String message) async {
    // Mykey mykey = await IdentityService().getDefaultMykey();
    // NostrEvent event = NostrEvent.from(
    //     kind: EventKinds.NIP42,
    //     tags: [
    //       ["relay", relay.url],
    //       ["challenge", msg1[1]]
    //     ],
    //     content: '',
    //     privkey: mykey.prikey);

    // String serializeStr = event.serialize('AUTH');
    // logger.i('auth: $serializeStr');
    // sendMessageFunction(serializeStr);
  }

  _processEvent(List eventList, Relay relay, String message) async {
    NostrEventModel event =
        NostrEventModel.deserialize(eventList, verify: false);
    // logger.i('${DateTime.now()} : ${event.createdAt}');
    switch (event.kind) {
      case EventKinds.contactList:
        await await _processNip2(event);
        break;
      case EventKinds.encryptedDirectMessage:
      case EventKinds.nip17:
        await await _processNip4Message(eventList, event, relay);
        break;
      case EventKinds.setMetadata:
        await _processNip5(event);
        break;
      case EventKinds.textNote:
        await Get.find<WorldController>().processEvent(event);
        break;
      default:
        logger.i('revived: $eventList');
    }
  }

  _processWriteEventResponse(List msg, Relay relay) async {
    String eventId = msg[1];
    bool status = msg[2];
    String? errorMessage = msg[3];
    bool exist = WriteEventStatus.fillSubscripton(
        eventId, relay.url, status, errorMessage);
    if (exist) return;

    WriteEventStatus.updateEventStatus(relay.url, eventId, status, msg[3]);
  }

  _processNip2(NostrEventModel msg) async {
    // List profiles = Nip2.decode(msg);
    // Mykey mykey = await IdentityService().getDefaultMykey();
    // for (var profile in profiles) {
    //   await contactService.updateContact(
    //       identityId: mykey.identity.value!.id,
    //       pubkey: profile['pubkey'],
    //       petname: profile['petname']);
    // }
  }

  _processNip5(NostrEventModel event) async {
    try {
      Map decodedContent = jsonDecode(event.content);
      if (decodedContent.keys.isEmpty) return;
      List contacts = await ContactService().getContacts(event.pubkey);
      if (contacts.isEmpty) return;
      for (Contact contact in contacts) {
        if (decodedContent['name'] != null) {
          contact.name = decodedContent['name'];
        }

        if (decodedContent['about'] != null) {
          contact.about = decodedContent['about'];
        }

        if (decodedContent['picture'] != null) {
          contact.picture = decodedContent['picture'];
        }

        if (decodedContent['hisRelay'] != null) {
          contact.hisRelay = decodedContent['hisRelay'];
        }
        Room? room;
        if (decodedContent['bot'] != null) {
          if (decodedContent['bot'] == 1) {
            // if contact is bot, then encrypt with nip04
            contact.isBot = true;
            Identity identity =
                Get.find<HomeController>().identities[contact.identityId]!;
            room = await RoomService().getOrCreateRoom(
                contact.pubkey, identity.secp256k1PKHex, RoomStatus.enabled);
            room.encryptMode = EncryptMode.nip04;
            RoomService().updateRoom(room);
          }
        }

        contact.updatedAt = DateTime.now();
        await ContactService().saveContact(contact, sync: false);
        if (room != null) {
          RoomService().updateChatRoomPage(room);
        }
      }
      Get.find<HomeController>().loadRoomList();
    } catch (e, s) {
      logger.e('update user metadata', error: e, stackTrace: s);
    }
  }

  Future syncContact(String pubkey) async {
    Request requestWithFilter = Request(utils.generate64RandomHexChars(), [
      Filter(
        kinds: [EventKinds.contactList],
        authors: [pubkey],
        limit: 1000,
      )
    ]);
    var req = requestWithFilter.serialize();
    Get.find<WebsocketService>().sendRawReq(req);
    return requestWithFilter;
  }

  /// sync contact to relay
  sendNip2Message(int identityId) async {
    // List<Contact> contacts = await contactService.getContactList(identityId);
    // Mykey mykey = await IdentityService().getDefaultMykey();

    // List<List<String>> tags = Nip2.toTags(contacts);
    // var event = NostrEvent.from(
    //   kind: EventKinds.CONTACT_LIST,
    //   tags: tags,
    //   content: "",
    //   privkey: mykey.prikey,
    // );
    // var req = event.serialize();
    // // logger.i('contact: $req');
    // _socket.writeReq(req);
    // return event;
  }

  Future<SendMessageResponse> sendNip4Message(
      String toPublicKey, String toEncryptText,
      {bool save = true,
      required String prikey,
      required String from,
      required Room room,
      required MessageEncryptType encryptType,
      MessageMediaType? mediaType,
      MsgReply? reply,
      bool? isSystem,
      String? realMessage,
      String? sourceContent,
      bool isSignalMessage = false,
      String? msgKeyHash}) async {
    late String encryptedEvent;
    if (isSignalMessage) {
      encryptedEvent = await rustNostr.getUnencryptEvent(
          senderKeys: prikey,
          receiverPubkey: toPublicKey,
          content: toEncryptText);
    } else {
      encryptedEvent = await rustNostr.getEncryptEvent(
          senderKeys: prikey,
          receiverPubkey: toPublicKey,
          content: toEncryptText);
    }
    NostrEventModel event =
        NostrEventModel.fromJson(jsonDecode(encryptedEvent), verify: false);
    String? hisRelay;
    if (room.type == RoomType.common) {
      room.contact ??=
          await ContactService().getContact(room.identityId, room.toMainPubkey);
      hisRelay = room.contact?.hisRelay;
    }
    List<String> relays = await Get.find<WebsocketService>().writeNostrEvent(
        event: event,
        encryptedEvent: encryptedEvent,
        roomId: room.parentRoom?.id ?? room.id,
        hisRelay: hisRelay);
    if (save && relays.isEmpty) {
      throw Exception(ErrorMessages.relayIsEmptyException);
    }
    if (!save) {
      return SendMessageResponse(
          events: [event], relays: relays, msgKeyHash: msgKeyHash);
    }
    var model = await MessageService().saveMessageToDB(
        events: [event],
        reply: reply,
        from: from,
        to: toPublicKey,
        isSystem: isSystem ?? false,
        idPubkey: room.myIdPubkey,
        content: sourceContent ?? toEncryptText,
        realMessage: realMessage,
        isRead: true,
        isMeSend: true,
        room: room,
        mediaType: mediaType,
        encryptType: encryptType,
        msgKeyHash: msgKeyHash);

    await dbProvider.saveMyEventLog(event: event, relays: relays);
    return SendMessageResponse(events: [event], relays: relays, message: model);
  }

  Future<SendMessageResponse> sendAndSaveGiftMessage(
    String to,
    String sourceContent, {
    required String encryptedEvent,
    required String from,
    required Room room,
    bool save = true,
    MessageMediaType? mediaType,
    MsgReply? reply,
    bool? isSystem,
    String? realMessage,
  }) async {
    NostrEventModel event =
        NostrEventModel.fromJson(jsonDecode(encryptedEvent), verify: false);
    String? hisRelay;
    if (room.type == RoomType.common) {
      room.contact ??=
          await ContactService().getContact(room.identityId, room.toMainPubkey);
      hisRelay = room.contact?.hisRelay;
    }
    List<String> relays = await Get.find<WebsocketService>().writeNostrEvent(
        event: event,
        encryptedEvent: encryptedEvent,
        roomId: room.parentRoom?.id ?? room.id,
        hisRelay: hisRelay);
    if (save && relays.isEmpty) {
      throw Exception(ErrorMessages.relayIsEmptyException);
    }
    if (!save) {
      return SendMessageResponse(events: [event], relays: relays);
    }
    var model = await MessageService().saveMessageToDB(
        events: [event],
        reply: reply,
        from: from,
        to: to,
        isSystem: isSystem ?? false,
        idPubkey: room.myIdPubkey,
        content: sourceContent,
        realMessage: realMessage,
        isRead: true,
        isMeSend: true,
        room: room,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        mediaType: mediaType,
        encryptType: MessageEncryptType.nip17);

    await dbProvider.saveMyEventLog(event: event, relays: relays);
    return SendMessageResponse(events: [event], relays: relays, message: model);
  }

  Future<String?> getDecodeNip4Content(NostrEventModel event) async {
    String decodePubkey = event.tags[0][1];
    String? prikey = await IdentityService().getPrikeyByPubkey(decodePubkey);
    if (prikey == null) return null;
    try {
      return await rustNostr.decrypt(
          senderKeys: prikey,
          receiverPubkey: event.pubkey,
          content: event.content);
    } catch (e) {
      logger.e('decrypt error', error: e);
    }
    return null;
  }

  static final Map<String, List<int>> _lastMessageAtMap = {};
  _updateRelayLastMessageAt(String url, int createdAt) async {
    if (_lastMessageAtMap[url] == null) {
      _lastMessageAtMap[url] = [];
    }
    _lastMessageAtMap[url]!.add(createdAt);

    EasyDebounce.debounce(
        '_updateRelayLastMessageAt$url', const Duration(seconds: 1), () async {
      NostrAPI._lastMessageAtMap[url]!.sort((a, b) => b.compareTo(a));
      int lastAt = NostrAPI._lastMessageAtMap[url]!.last;
      NostrAPI._lastMessageAtMap[url] = [];

      String key = '${StorageKeyString.lastMessageAt}:$url';
      int lastMessageAt = await Storage.getIntOrZero(key);
      if (lastAt > lastMessageAt) {
        await Storage.setInt(key, lastAt);
      }
    });
  }

  _processNip4Message(
      List eventList, NostrEventModel event, Relay relay) async {
    if (processedEventIds.contains(event.id)) {
      logger.i('duplicate: ${event.id}');
      return;
    } else {
      processedEventIds.add(event.id);
    }

    _updateRelayLastMessageAt(relay.url, event.createdAt);
    EventLog? exist = await dbProvider.getEventLog(event.id, event.tags[0][1]);

    // verify
    try {
      await rustNostr.verifyEvent(json: jsonEncode(eventList[2]));
    } catch (e, s) {
      if (e is AnyhowException) {
        if (e.message.contains('malformed public key')) {
          exist?.setNote('malformed public key');
          return;
        }
      }

      exist?.setNote('verify error');
      logger.e('verify error', error: e, stackTrace: s);
    }
    // verify success
    //
    if (exist != null) {
      if (exist.resCode == 0) {
        exist.resCode = 200;
        exist.updatedAt = DateTime.now();
        exist.okRelays = [...exist.okRelays, relay.url];
        await dbProvider.updateEventLog(exist);
      }
      return;
    }
    // logNostrEventK4(relay, event);
    exist = await dbProvider.receiveNewEventLog(event: event, relay: relay.url);
    switch (event.kind) {
      case EventKinds.encryptedDirectMessage:
        try {
          if (event.isNip4) {
            return await dmNip4Proccess(event, relay, exist);
          }

          // if signal message , to_address is myIDPubkey or one-time-key
          String to = event.tags[0][1];
          Room? room = await roomService.getRoomByReceiveKey(to);
          if (room != null) {
            return await SignalChatService()
                .decryptDMMessage(room, event, relay, eventLog: exist);
          }
          Mykey? mykey = await IdentityService().getMykeyByPubkey(to);
          if (mykey != null) {
            return await SignalChatService().decryptPreKeyMessage(to, mykey,
                event: event, relay: relay, eventLog: exist);
          }
          logger.e('signal message decrypt error');
        } catch (e, s) {
          exist.setNote('signal message decrypt error');
          logger.e('signal message decrypt error', error: e, stackTrace: s);
        }

        break;
      case EventKinds.nip17:
        try {
          await _processNip17Message(event, relay);
        } catch (e, s) {
          logger.e('nip17 decrypt error', error: e, stackTrace: s);
        }
        break;
      default:
    }
  }

  Future dmNip4Proccess(
      NostrEventModel event, Relay relay, EventLog? eventLog) async {
    // try kdf group
    String to = event.tags[0][1];
    Room? kdfRoom = await roomService.getGroupByReceivePubkey(to);
    if (kdfRoom != null) {
      return await KdfGroupService.instance
          .decryptMessage(kdfRoom, event, relay, eventLog: eventLog);
    }

    String? content = await getDecodeNip4Content(event);
    if (content == null) {
      logger.e('decode error: ${event.id}');
      eventLog?.setNote('Nip04 decode error');
      return;
    }

    dynamic decodedContent;
    try {
      decodedContent = jsonDecode(content);
    } catch (e) {
      return await Nip4ChatService().receiveNip4Message(event, content);
    }
    // keychatMessage class message
    if (decodedContent is Map<String, dynamic>) {
      return await roomService.processKeychatMessage(
          event, decodedContent, relay);
    }

    // nip4(nip4/signal) message
    if (decodedContent is List) {
      await _processSubEvent(event, relay, content, decodedContent);
      return;
    }

    return await Nip4ChatService().receiveNip4Message(event, content);
  }

  _processSubEvent(NostrEventModel event, Relay relay, String content,
      List decodedContent) async {
    NostrEventModel subEvent = NostrEventModel.deserialize(decodedContent);
    if (subEvent.kind != EventKinds.encryptedDirectMessage) return;

    // nip4(nip4)
    if (subEvent.isNip4) {
      String? subContent = await getDecodeNip4Content(subEvent);
      if (subContent == null) {
        return await Nip4ChatService().receiveNip4Message(event, content);
      }
      // logger.i(subContent);
      dynamic subDecodedContent;
      try {
        subDecodedContent = jsonDecode(subContent);
      } catch (e) {
        logger.d('try decode error');
      }
      // sub content is KeychatMessage Object
      if (subDecodedContent is Map<String, dynamic>) {
        return await roomService.processKeychatMessage(
            subEvent, subDecodedContent, relay, event);
      }
      return await Nip4ChatService().receiveNip4Message(subEvent, subContent);
    }

    // nip4(signal)
    Room room = await roomService.getOrCreateRoom(
        subEvent.pubkey, subEvent.tags[0][1], RoomStatus.init);
    return await SignalChatService()
        .decryptDMMessage(room, subEvent, relay, sourceEvent: event);
  }

  updateMyMetadata({
    required String name,
    String about = '',
    String picture = '',
  }) async {
    // Map data = {"name": name, "about": about, "picture": picture};
    // Mykey mainMykey = await IdentityService().getDefaultMykey();
    // NostrEvent event = NostrEvent.from(
    //     kind: EventKinds.SET_METADATA,
    //     tags: [],
    //     content: jsonEncode(data),
    //     privkey: mainMykey.prikey);
    // _socket.writeReq(event.serialize());

    // mainMykey.name = name;
    // await IdentityService().updateMykey(mainMykey);
  }

  Future subscripAllMetaData() async {
    Identity identity = Get.find<HomeController>().identities[0]!;
    List<Contact> contacts = await ContactService().getContactList(identity.id);
    if (contacts.isEmpty) return;

    List<String> pubkeys = contacts.map((e) => e.pubkey).toList();
    if (pubkeys.isNotEmpty && nip05SubscriptionId.isNotEmpty) {
      Get.find<WebsocketService>()
          .sendRawReq(closeSerialize(nip05SubscriptionId));
    }

    nip05SubscriptionId = await fetchMetadata(pubkeys);
  }

  Future<String> fetchMetadata(List<String> pubkeys) async {
    String id = utils.generate64RandomHexChars();
    Request requestWithFilter = Request(id, [
      Filter(
        kinds: [EventKinds.setMetadata],
        authors: pubkeys,
        limit: 100,
      )
    ]);

    var req = requestWithFilter.serialize();

    Get.find<WebsocketService>().sendRawReq(req);
    return id;
  }

  void _proccessNotice(Relay relay, String msg1) {
    var ws = Get.find<WebsocketService>();
    if (ws.channels[relay.url] == null) return;
    ws.channels[relay.url]!.notices.add(msg1);
  }

  Future _processNip17Message(NostrEventModel event, Relay relay) async {
    String to = event.tags[0][1];
    String? myPrivateKey;
    Identity? identity = await IdentityService().getIdentityByNostrPubkey(to);
    if (identity != null) {
      myPrivateKey = identity.secp256k1SKHex;
    } else {
      Mykey? mykey = await IdentityService().getMykeyByPubkey(to);
      if (mykey != null) {
        myPrivateKey = mykey.prikey;
      }
    }
    if (myPrivateKey == null) {
      logger.e('myPrivateKey is null');
      return;
    }

    NostrEvent result = await rustNostr.decryptGift(
        senderKeys: myPrivateKey,
        receiver: event.pubkey,
        content: event.content);
    var subEvent = NostrEventModel(
        result.id,
        result.pubkey,
        result.createdAt.toInt(),
        result.kind.toInt(),
        result.tags,
        result.content,
        result.sig,
        verify: false);

    dynamic decodedContent;
    try {
      decodedContent = jsonDecode(subEvent.content);
    } catch (e) {
      return await Nip4ChatService()
          .receiveNip4Message(subEvent, subEvent.content, event);
    }
    if (decodedContent is Map<String, dynamic>) {
      return await roomService.processKeychatMessage(
          subEvent, decodedContent, relay, event);
    }

    await Nip4ChatService()
        .receiveNip4Message(subEvent, subEvent.content, event);
  }
}
