import 'dart:convert' show jsonDecode, utf8, base64, base64Decode;
import 'dart:typed_data' show Uint8List;

import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr_event.dart';

import 'package:app/service/chat.service.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/service/storage.dart';
import 'package:convert/convert.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rustSignal;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;

import 'package:app/service/nip4Chat.service.dart';

import '../constants.dart';
import '../nostr-core/nostr.dart';
import '../utils.dart';
import 'message.service.dart';
import 'contact.service.dart';
import 'room.service.dart';

class SignalChatService extends BaseChatService {
  static final SignalChatService _singleton = SignalChatService._internal();
  factory SignalChatService() {
    return _singleton;
  }

  SignalChatService._internal();

  @override
  Future<SendMessageResponse> sendMessage(
    Room room,
    String message, {
    bool save = true,
    bool? isSystem,
    MsgReply? reply,
    String? realMessage,
    MessageMediaType? mediaType,
    Function? sentCallback,
  }) async {
    ChatxService cs = Get.find<ChatxService>();

    String message0 = message;
    rustSignal.KeychatProtocolAddress? kpa = await cs.getRoomKPA(room);
    if (kpa == null) {
      throw Exception("signal_session_is_null");
    }
    final keyPair = cs.getKeyPair(room.getIdentity());
    (Uint8List, String?, String, List<String>?) enResult = await rustSignal
        .encryptSignal(keyPair: keyPair, ptext: message0, remoteAddress: kpa);
    Uint8List ciphertext = enResult.$1;
    String? myReceiverAddr;
    if (enResult.$2 != null) {
      myReceiverAddr =
          await rustNostr.generateSeedFromRatchetkeyPair(seedKey: enResult.$2!);
    }
    String msgKeyHash =
        await rustNostr.generateMessageKeyHash(seedKey: enResult.$3);

    List<String>? toAddPubkeys;

    // listen and sub new receive address
    if (myReceiverAddr != null) {
      toAddPubkeys = await ContactService()
          .addReceiveKey(room.identityId, room.toMainPubkey, myReceiverAddr);

      if (save && toAddPubkeys.isNotEmpty) {
        Get.find<WebsocketService>().listenPubkey(toAddPubkeys,
            since: DateTime.now().subtract(const Duration(seconds: 5)));
        if (!room.isMute) NotifyService.addPubkeys(toAddPubkeys);
      }
    }
    rustSignal.KeychatSignalSession? bobSession = await rustSignal.getSession(
        keyPair: keyPair,
        address: room.curve25519PkHex!,
        deviceId: room.identityId.toString());

    String to = await _getToAddress(bobSession, room);
    String encryptedContent = base64.encode(ciphertext);
    bool isSendToOnetimeKey =
        to == room.toMainPubkey && room.onetimekey != null;
    if (isSendToOnetimeKey) {
      to = room.onetimekey!;
    }
    // if (to == room.toMainPubkey || isSendToOnetimeKey) {
    //   encryptedContent = await rustNostr.getUnencryptEvent(
    //       senderKeys: (room.getIdentity()).secp256k1SKHex,
    //       receiverPubkey: to,
    //       content: encryptedContent);

    //   encryptedContent = "[\"EVENT\",$encryptedContent]";
    // }
    var senderKey = await rustNostr.generateSimple();

    SendMessageResponse smr = await NostrAPI().sendNip4Message(
        to, encryptedContent,
        save: save,
        prikey: senderKey.prikey,
        from: senderKey.pubkey,
        room: room,
        isSystem: isSystem,
        encryptType: MessageEncryptType.signal,
        realMessage: realMessage,
        sourceContent: message0,
        reply: reply,
        mediaType: mediaType,
        isSignalMessage: true,
        msgKeyHash: msgKeyHash);
    smr.toAddPubkeys = toAddPubkeys;
    return smr;
  }

  Future<String> _getToAddress(
      rustSignal.KeychatSignalSession? bobSession, Room room) async {
    String to = bobSession!.bobAddress ?? bobSession.address;

    if (to.startsWith('05')) {
      to = room.toMainPubkey;
    } else {
      to = await rustNostr.generateSeedFromRatchetkeyPair(seedKey: to);
    }
    return to;
  }

  Future<String> decryptDMMessage(Room room, NostrEventModel event, Relay relay,
      {NostrEventModel? sourceEvent, EventLog? eventLog}) async {
    ChatxService cs = Get.find<ChatxService>();

    final keyPair = cs.getKeyPair(room.getIdentity());
    Uint8List message = Uint8List.fromList(base64Decode(event.content));

    late Uint8List plaintext;
    String? msgKeyHash;
    try {
      rustSignal.KeychatProtocolAddress? kpa =
          await Get.find<ChatxService>().getRoomKPA(room);
      if (kpa == null) {
        eventLog?.setNote('signal_session_is_null');
        throw Exception("signal_session_is_null");
      }
      try {
        (plaintext, msgKeyHash, _) = await rustSignal.decryptSignal(
            keyPair: keyPair,
            ciphertext: message,
            remoteAddress: kpa,
            roomId: room.id,
            isPrekey: false);
      } catch (e, s) {
        String msg = Utils.getErrorMessage(e);
        logger.i(msg, error: e, stackTrace: s);
        // first msg in decryptSignal must be isPrekey = true
        (plaintext, msgKeyHash, _) = await rustSignal.decryptSignal(
            keyPair: keyPair,
            ciphertext: message,
            remoteAddress: kpa,
            roomId: room.id,
            isPrekey: true);
      }
      await setRoomSignalDecodeStatus(room, false);
      // get hash
      msgKeyHash = await rustNostr.generateMessageKeyHash(seedKey: msgKeyHash);
      // if receive address is signalAddress, then remove room.onetimekey
      if (room.onetimekey != null) {
        String toAddress = (sourceEvent ?? event).tags[0][1];
        if (toAddress != room.toMainPubkey && toAddress != room.onetimekey!) {
          room.onetimekey = null;
          await RoomService().updateRoom(room);
        }
      }
      ContactService().deleteReceiveKey(
          room.identityId, room.toMainPubkey, event.tags[0][1]);
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
      await setRoomSignalDecodeStatus(room, true);
      eventLog?.setNote('Signal Decryption failed');

      plaintext =
          Uint8List.fromList(utf8.encode("Decryption failed: ${e.toString()}"));
    }

    String decodeString = utf8.decode(plaintext);

    Map<String, dynamic> decodedContent;
    KeychatMessage? km;
    try {
      decodedContent = jsonDecode(decodeString);
      km = KeychatMessage.fromJson(decodedContent);
    } catch (e) {
      // logger.e('decodeString error,', error: e);
    }

    if (km != null) {
      await km.service.processMessage(
          room: room,
          event: event,
          km: km,
          msgKeyHash: msgKeyHash,
          sourceEvent: sourceEvent,
          relay: relay);
      return decodeString;
    }
    await RoomService().receiveDM(
        room,
        event,
        KeychatMessage(type: KeyChatEventKinds.dm, c: MessageType.signal)
          ..msg = decodeString,
        sourceEvent,
        msgKeyHash: msgKeyHash);
    return decodeString;
  }

  Future<void> setRoomSignalDecodeStatus(
      Room room, bool signalDecodeError) async {
    if (signalDecodeError == room.signalDecodeError) return;

    room.signalDecodeError = signalDecodeError;
    await RoomService().updateRoom(room);
    RoomService().updateChatRoomPage(room);
  }

  @override
  processMessage(
      {required Room room,
      required NostrEventModel event,
      required KeychatMessage km,
      NostrEventModel? sourceEvent,
      String? msgKeyHash,
      required Relay relay}) async {
    switch (km.type) {
      case KeyChatEventKinds.dm: // commom chat, may be contain: reply
        await RoomService()
            .receiveDM(room, event, km, sourceEvent, msgKeyHash: msgKeyHash);
        break;
      case KeyChatEventKinds.dmAddContactFromAlice:
      case KeyChatEventKinds.dmAddContactFromBob:
        RoomService().checkMessageValid(room, sourceEvent ?? event);
        await _processHelloMessage(room, event, km, sourceEvent);
        break;
      case KeyChatEventKinds.dmReject:
        RoomService().checkMessageValid(room, sourceEvent ?? event);
        await _processReject(room, event, km, sourceEvent);
        break;
      case KeyChatEventKinds.signalRelaySyncInvite:
        RoomService().checkMessageValid(room, sourceEvent ?? event);
        await _processRelaySyncMessage(room, event, km, sourceEvent);
        break;
      default:
    }
  }

  // Future<SendMessageResponse> _sendFeatureMessage(
  //     Room room, KeychatMessage sm, String realMessage,
  //     {bool isSystem = false}) async {
  //   return await Nip4ChatService().sendIncognitoNip4Message(
  //       room, jsonEncode(sm),
  //       realMessage: realMessage, isSystem: isSystem);
  // }

  processListenAddrs(String address, String mapKey) async {
    List<String> sourceList = await Storage.getStringList(mapKey);

    // null
    if (sourceList.isEmpty) {
      await Storage.setStringList(mapKey, [address]);
      return ([address], <String>[]);
    }
    // equal
    if (sourceList.last == address) return (<String>[], <String>[]);

    // add
    List<String> addList = [address];
    List<String> removeList = [];
    int maxListenAddrs = 3;
    sourceList.add(address);

    // check if need remove
    if (sourceList.length > maxListenAddrs) {
      removeList = sourceList.sublist(0, 1);
      sourceList = sourceList.sublist(1);
    }
    await Storage.setStringList(mapKey, sourceList);
    return (addList, removeList);
  }

  _processHelloMessage(Room room, NostrEventModel event,
      KeychatMessage keychatMessage, NostrEventModel? sourceEvent) async {
    if (keychatMessage.name == null) {
      logger.i('name is null');
      return;
    }

    var model = QRUserModel.fromJson(jsonDecode(keychatMessage.name!));

    Contact contact = await ContactService()
        .getOrCreateContact(room.identityId, room.toMainPubkey);

    // update contact name
    if (contact.name != model.name) {
      contact.name = model.name;
      await ContactService().saveContact(contact);
    }
    // auto send response
    Mykey? oneTimeKey = await IdentityService()
        .isFromOnetimeKey((sourceEvent ?? event).tags[0][1]);

    // expire onetime-key
    if (oneTimeKey != null) {
      oneTimeKey.oneTimeUsed = true;
      oneTimeKey.updatedAt = DateTime.now();
      await IdentityService().updateMykey(oneTimeKey);
    }

    if (room.status == RoomStatus.requesting) {
      room.status = RoomStatus.enabled;
    } else if (room.status != RoomStatus.enabled) {
      room.status = oneTimeKey != null
          ? RoomStatus.approvingNoResponse
          : RoomStatus.approving;
    }
    // use onetime key to response
    if (keychatMessage.type == KeyChatEventKinds.dmAddContactFromAlice) {
      room.onetimekey = model.onetimekey;
    }

    room.curve25519PkHex = model.curve25519PkHex;
    await Get.find<ChatxService>()
        .deleteSignalSessionKPA(room); // delete old session
    bool res = await Get.find<ChatxService>().addRoomKPA(
        room: room,
        bobSignedId: model.signedId,
        bobSignedPublic: Uint8List.fromList(hex.decode(model.signedPublic)),
        bobSignedSignature: Uint8List.fromList(
          hex.decode(model.signedSignature),
        ),
        bobPrekeyId: model.prekeyId,
        bobPrekeyPublic: Uint8List.fromList(hex.decode(model.prekeyPubkey)));
    if (res) {
      // logger.i('signal session create success');
      room.encryptMode = EncryptMode.signal;
    }

    room = await RoomService().updateRoom(room);
    room.contact = contact;
    await RoomService().receiveDM(room, event, keychatMessage, sourceEvent,
        realMessage: keychatMessage.msg);

    // auto response
    if (room.status == RoomStatus.enabled &&
        keychatMessage.type == KeyChatEventKinds.dmAddContactFromAlice) {
      await sendHelloMessage(room, room.getIdentity(),
          type: KeyChatEventKinds.dmAddContactFromBob);
    }
    RoomService().updateChatRoomPage(room);
  }

  Future sendHelloMessage(Room room, Identity identity,
      {int type = KeyChatEventKinds.dmAddContactFromAlice,
      String? onetimekey,
      String? greeting}) async {
    KeychatMessage sm = await KeychatMessage(c: MessageType.signal, type: type)
        .setHelloMessagge(identity, greeting: greeting);
    await Nip4ChatService().sendIncognitoNip4Message(
      room,
      sm.toString(),
      toAddress: onetimekey,
      realMessage: sm.msg,
      isSystem: true,
    );
    return;
  }

  Future sendHelloMessage2(Room room, Identity identity,
      {String? greeting}) async {
    KeychatMessage sm = KeychatMessage(
        c: MessageType.signal, type: KeyChatEventKinds.dmAddContactFromBobV2)
      ..msg = identity.secp256k1PKHex
      ..name = identity.displayName;

    var res = await SignalChatService().sendMessage(
      room,
      sm.toString(),
      realMessage: sm.msg,
    );
    logger.d('sendHelloMessage2: $res');
    return;
  }

  Future _processRelaySyncMessage(Room room, NostrEventModel event,
      KeychatMessage keychatMessage, NostrEventModel? sourceEvent) async {
    String realMessage = '''My receiveInPostOffice is:
**${keychatMessage.msg}** 
Let's talk on this server.''';

    await MessageService().saveMessageToDB(
        from: sourceEvent?.pubkey ?? event.pubkey,
        to: sourceEvent?.tags[0][1] ?? event.tags[0][1],
        idPubkey: room.toMainPubkey,
        events: [sourceEvent ?? event],
        room: room,
        isMeSend: false,
        isSystem: true,
        encryptType: MessageEncryptType.signal,
        sent: SendStatusType.success,
        mediaType: MessageMediaType.setPostOffice,
        requestConfrim: RequestConfrimEnum.request,
        content: keychatMessage.msg ?? '',
        realMessage: realMessage);
  }

  void sendRelaySyncMessage(Room room, String relay) async {
    KeychatMessage sm = KeychatMessage(
        c: MessageType.signal,
        type: KeyChatEventKinds.signalRelaySyncInvite,
        msg: relay);
    String realMessage = '''My receiveInPostOffice is:
**$relay**
Let's talk on this server.''';

    await RoomService().sendTextMessage(
      room,
      sm.toString(),
      realMessage: realMessage,
      isSystem: true,
    );
  }

  Future sendRejectMessage(Room room) async {
    KeychatMessage sm =
        KeychatMessage(c: MessageType.signal, type: KeyChatEventKinds.dmReject);

    await RoomService().sendTextMessage(
      room,
      sm.toString(),
      realMessage: 'Reject',
      encryptMode: EncryptMode.nip04,
      isSystem: true,
    );
  }

  Future _processReject(Room room, NostrEventModel event, KeychatMessage km,
      NostrEventModel? sourceEvent) async {
    room.status = RoomStatus.rejected;
    await RoomService()
        .receiveDM(room, event, km, sourceEvent, realMessage: 'Rejected');

    await RoomService().updateRoom(room);
    RoomService().updateChatRoomPage(room);
    await Get.find<HomeController>().loadIdentityRoomList(room.identityId);
  }
}
