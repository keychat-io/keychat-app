import 'package:app/models/nostr_event_status.dart';
import 'package:app/nostr-core/subscribe_result.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

import 'package:queue/queue.dart';
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:app/controller/world.controller.dart';

import 'package:app/models/models.dart';
import 'package:app/nostr-core/filter.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/nostr-core/subscribe_event_status.dart';

import 'package:app/nostr-core/request.dart';
import 'package:app/service/secure_storage.dart';

import 'package:app/service/identity.service.dart';
import 'package:app/service/kdf_group.service.dart';
import 'package:app/service/nip4_chat.service.dart';
import 'package:app/service/signal_chat.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart';

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
  Set<String> processedEventIds = {};
  String nip05SubscriptionId = '';
  final nostrEventQueue = Queue(
      delay: const Duration(milliseconds: kReleaseMode ? 50 : 200),
      timeout: const Duration(seconds: 5),
      parallel: 1);
  static final NostrAPI _instance = NostrAPI._internal();
  NostrAPI._internal();

  factory NostrAPI() => _instance;

  String closeSerialize(String subscriptionId) {
    return jsonEncode(["CLOSE", subscriptionId]);
  }

  addNostrEventToQueue(Relay relay, dynamic message) {
    //logger.d('processWebsocketMessage, ${relay.url} $message');
    nostrEventQueue.add(() async {
      try {
        var res = jsonDecode(message);
        switch (res[0]) {
          case NostrResKinds.ok:
            loggerNoLine.i('OK: ${relay.url}, $res');
            await _proccessWriteEventResponse(res, relay);
            break;
          case NostrResKinds.event:
            loggerNoLine.i('receive event: ${relay.url} $message');
            await _proccessEvent(res, relay, message);
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
      } catch (e, s) {
        logger.e('processWebsocketMessage', error: e, stackTrace: s);
      }
    });
  }

  _proccessEOSE(Relay relay, List res) async {
    String key = '${StorageKeyString.lastMessageAt}:${relay.url}';
    int lastMessageAt = await Storage.getIntOrZero(key);
    if (lastMessageAt == 0) return;

    DateTime? messageTime = await MessageService().getLastMessageTime();
    if (messageTime == null) return;
    if (lastMessageAt > (messageTime.millisecondsSinceEpoch ~/ 1000)) {
      return;
    }

    Storage.setInt(key, lastMessageAt + 1);
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

  Future _proccessEvent(List eventList, Relay relay, String raw) async {
    NostrEventModel event =
        NostrEventModel.deserialize(eventList, verify: false);
    String subscribeId = eventList[1];
    // logger.i('${DateTime.now()} : ${event.createdAt}');
    switch (event.kind) {
      case EventKinds.contactList:
        await _proccessNip2(event);
        break;
      case EventKinds.encryptedDirectMessage:
      case EventKinds.nip17:
        await _processNip4Message(eventList, event, relay, raw);
        break;
      case EventKinds.setMetadata:
        SubscribeResult.instance.fill(subscribeId, event);
        break;
      case EventKinds.textNote:
        await Get.find<WorldController>().processEvent(event);
        break;
      default:
        logger.i('revived: $eventList');
    }
  }

  _proccessWriteEventResponse(List msg, Relay relay) async {
    String eventId = msg[1];
    bool status = msg[2];
    String? errorMessage = msg[3];
    SubscribeEventStatus.fillSubscripton(
        eventId, relay.url, status, errorMessage);
  }

  _proccessNip2(NostrEventModel msg) async {
    // List profiles = Nip2.decode(msg);
    // Mykey mykey = await IdentityService().getDefaultMykey();
    // for (var profile in profiles) {
    //   await contactService.updateContact(
    //       identityId: mykey.identity.value!.id,
    //       pubkey: profile['pubkey'],
    //       petname: profile['petname']);
    // }
  }

  _proccessNip5(NostrEventModel event) async {
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

        contact.updatedAt = DateTime.now();
        await ContactService().saveContact(contact, sync: false);
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
      encryptedEvent = await rust_nostr.getUnencryptEvent(
          senderKeys: prikey,
          receiverPubkey: toPublicKey,
          content: toEncryptText);
    } else {
      encryptedEvent = await rust_nostr.getEncryptEvent(
          senderKeys: prikey,
          receiverPubkey: toPublicKey,
          content: toEncryptText);
    }
    NostrEventModel event =
        NostrEventModel.fromJson(jsonDecode(encryptedEvent), verify: false);

    List relays = await Get.find<WebsocketService>().writeNostrEvent(
        event: event,
        eventString: encryptedEvent,
        roomId: room.parentRoom?.id ?? room.id,
        toRelays: room.sendingRelays);
    if (save && relays.isEmpty) {
      throw Exception(ErrorMessages.relayIsEmptyException);
    }
    if (!save) {
      return SendMessageResponse(events: [event], msgKeyHash: msgKeyHash);
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
    return SendMessageResponse(events: [event], message: model);
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
    List relays = await Get.find<WebsocketService>().writeNostrEvent(
        event: event,
        eventString: encryptedEvent,
        roomId: room.parentRoom?.id ?? room.id,
        toRelays: room.sendingRelays);
    if (save && relays.isEmpty) {
      throw Exception(ErrorMessages.relayIsEmptyException);
    }
    if (!save) {
      return SendMessageResponse(events: [event]);
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

    return SendMessageResponse(events: [event], message: model);
  }

  Future<String?> decryptNip4Content(NostrEventModel event) async {
    String decodePubkey = event.tags[0][1];
    String? prikey = await IdentityService().getPrikeyByPubkey(decodePubkey);
    if (prikey == null) return null;
    try {
      return await rust_nostr.decrypt(
          senderKeys: prikey,
          receiverPubkey: event.pubkey,
          content: event.content);
    } catch (e) {
      logger.e('decryptNip4Content error', error: e);
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

  Future _processNip4Message(
      List eventList, NostrEventModel event, Relay relay, String raw) async {
    if (processedEventIds.contains(event.id)) {
      logger.i('duplicate_local: ${event.id}');
      return;
    } else {
      processedEventIds.add(event.id);
    }

    NostrEventStatus? ess = await NostrEventStatus.getReceiveEvent(event.id);
    if (ess != null) {
      logger.d('duplicate_db: ${event.id}');
      return;
    }
    logger.d('start proccess: ${event.id}');

    _updateRelayLastMessageAt(relay.url, event.createdAt);
    ess = await NostrEventStatus.createReceiveEvent(relay.url, event.id, raw);

    // verify
    try {
      await rust_nostr.verifyEvent(json: jsonEncode(eventList[2]));
    } catch (e, s) {
      logger.e('verify error', error: e, stackTrace: s);
      ess.setError(e.toString());
      return;
    }
    failedCallback(String error, [String? stackTrace]) {
      ess?.setError('proccess error: $error $stackTrace');
    }

    switch (event.kind) {
      case EventKinds.encryptedDirectMessage:
        String to = event.tags[0][1];
        try {
          if (event.isNip4) {
            Room? kdfRoom = await RoomService().getGroupByReceivePubkey(to);
            if (kdfRoom != null) {
              await _proccessByKDFRoom(event, kdfRoom, relay, failedCallback);
              return;
            }
            await dmNip4Proccess(event, relay, failedCallback);
            return;
          }

          // if signal message , to_address is myIDPubkey or one-time-key
          Room? room = await RoomService().getRoomByReceiveKey(to);
          if (room != null) {
            await SignalChatService().decryptMessage(room, event, relay,
                failedCallback: failedCallback);
            return;
          }
          Mykey? mykey = await IdentityService().getMykeyByPubkey(to);
          if (mykey != null) {
            await SignalChatService().decryptPreKeyMessage(to, mykey,
                event: event, relay: relay, failedCallback: failedCallback);
            return;
          }
          throw Exception('room not found');
        } catch (e, s) {
          ess.setError('nip04 ${e.toString()} ${s.toString()}');
          logger.e('decrypt error', error: e, stackTrace: s);
        }

        break;
      case EventKinds.nip17:
        try {
          await _processNip17Message(event, relay, failedCallback);
        } catch (e, s) {
          ess.setError('nip17 ${e.toString()} ${s.toString()}');
          logger.e('nip17 decrypt error', error: e, stackTrace: s);
        }
        break;
      default:
    }
  }

  Future _proccessByKDFRoom(NostrEventModel event, Room kdfRoom, Relay relay,
      Function(String error) failedCallback) async {
    String? content = await decryptNip4Content(event);
    if (content == null) {
      logger.e('decrypt error: ${event.toString()}');
      failedCallback('Nip04 decrypt error');
      return;
    }
    await KdfGroupService.instance.decryptMessage(kdfRoom, event,
        nip4DecodedContent: content, failedCallback: failedCallback);
  }

  Future dmNip4Proccess(NostrEventModel sourceEvent, Relay relay,
      Function(String error) failedCallback) async {
    String? content = await decryptNip4Content(sourceEvent);
    if (content == null) {
      logger.e('decryptNip4Content error: ${sourceEvent.id}');
      failedCallback('Nip04 ecrypt error');
      return;
    }

    dynamic decodedContent;
    try {
      decodedContent = jsonDecode(content);
    } catch (e) {
      await Nip4ChatService().receiveNip4Message(sourceEvent, content);
      return;
    }

    KeychatMessage? km = getKeyChatMessageFromJson(decodedContent);
    if (km != null) {
      await RoomService().processKeychatMessage(km, sourceEvent, relay);
      return;
    }

    // nip4(nip4/signal) message for old version
    NostrEventModel? subEvent;
    try {
      subEvent = NostrEventModel.deserialize(decodedContent);
    } catch (e) {}
    if (subEvent != null) {
      await _processSubEvent(sourceEvent, subEvent, relay, failedCallback);
      return;
    }

    await Nip4ChatService().receiveNip4Message(sourceEvent, content);
  }

  _processSubEvent(NostrEventModel event, NostrEventModel subEvent, Relay relay,
      Function(String error) failedCallback) async {
    // nip4(nip4)
    if (subEvent.isNip4) {
      String? subContent = await decryptNip4Content(subEvent);
      if (subContent == null) {
        return await Nip4ChatService()
            .receiveNip4Message(event, subEvent.serialize());
      }

      dynamic subDecodedContent;
      try {
        subDecodedContent = jsonDecode(subContent);
      } catch (e) {
        logger.d('try decode error');
        return await Nip4ChatService()
            .receiveNip4Message(subEvent, subContent, event);
      }

      KeychatMessage? km = getKeyChatMessageFromJson(subDecodedContent);
      if (km != null) {
        return await RoomService()
            .processKeychatMessage(km, subEvent, relay, event);
      }
      return await Nip4ChatService().receiveNip4Message(subEvent, subContent);
    }

    // nip4(signal)
    Room room = await RoomService()
        .getOrCreateRoom(subEvent.pubkey, subEvent.tags[0][1], RoomStatus.init);
    return await SignalChatService().decryptMessage(room, subEvent, relay,
        sourceEvent: event, failedCallback: failedCallback);
  }

  KeychatMessage? getKeyChatMessageFromJson(dynamic str) {
    try {
      return KeychatMessage.fromJson(str);
    } catch (e) {}
    return null;
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

  Future<dynamic> fetchMetadata(List<String> pubkeys) async {
    String id = utils.generate64RandomHexChars(16);
    Request requestWithFilter = Request(id, [
      Filter(kinds: [EventKinds.setMetadata], authors: pubkeys, limit: 2)
    ]);

    var req = requestWithFilter.serialize();
    return await Get.find<WebsocketService>().fetchInfoFromRelay(id, req);
  }

  void _proccessNotice(Relay relay, String msg1) {
    var ws = Get.find<WebsocketService>();
    if (ws.channels[relay.url] == null) return;
    ws.channels[relay.url]!.notices.add(msg1);
  }

  Future _processNip17Message(NostrEventModel event, Relay relay,
      Function(String) failedCallbackync) async {
    String to = event.tags[0][1];
    String? myPrivateKey;
    Identity? identity = await IdentityService().getIdentityByNostrPubkey(to);
    if (identity != null) {
      myPrivateKey = await SecureStorage.instance
          .readPrikeyOrFail(identity.secp256k1PKHex);
    } else {
      Mykey? mykey = await IdentityService().getMykeyByPubkey(to);
      if (mykey != null) {
        myPrivateKey = mykey.prikey;
      }
    }
    if (myPrivateKey == null) {
      logger.e('myPrivateKey is null');
      failedCallbackync('myPrivateKey is null');
      return;
    }

    NostrEvent result = await rust_nostr.decryptGift(
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
    KeychatMessage? km = getKeyChatMessageFromJson(decodedContent);

    if (km != null) {
      await RoomService().processKeychatMessage(km, subEvent, relay, event);
      return;
    }

    await Nip4ChatService()
        .receiveNip4Message(subEvent, subEvent.content, event);
  }
}
