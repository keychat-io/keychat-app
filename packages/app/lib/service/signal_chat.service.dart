import 'dart:convert' show base64, base64Decode, jsonDecode, jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:app/controller/home.controller.dart';
import 'package:app/models/keychat/prekey_message_model.dart';
import 'package:app/models/models.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/chat/RoomUtil.dart';

import 'package:app/service/chat.service.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/nip4_chat.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/signal_chat_util.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/service/storage.dart';
import 'package:convert/convert.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:keychat_rust_ffi_plugin/api_signal.dart';
import 'package:keychat_rust_ffi_plugin/index.dart';

import '../constants.dart';
import '../nostr-core/nostr.dart';
import '../utils.dart';
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
  }) async {
    ChatxService cs = Get.find<ChatxService>();
    rust_signal.KeychatProtocolAddress? kpa = await cs.getRoomKPA(room);
    if (kpa == null) {
      throw Exception("signal_session_is_null");
    }
    String message0 = message;
    var keypair = await room.getKeyPair();
    String to = await _getSignalToAddress(keypair, room);
    PrekeyMessageModel? pmm;
    if (room.onetimekey != null) {
      if (to == room.onetimekey) {
        pmm = await SignalChatUtil.getSignalPrekeyMessageContent(
            room, room.getIdentity(), message);
      }
    }

    (Uint8List, String?, String, List<String>?) enResult =
        await rust_signal.encryptSignal(
            keyPair: keypair,
            ptext: pmm?.toString() ?? message0,
            remoteAddress: kpa);
    Uint8List ciphertext = enResult.$1;
    String? myReceiverAddr;
    if (enResult.$2 != null) {
      myReceiverAddr = await rust_nostr.generateSeedFromRatchetkeyPair(
          seedKey: enResult.$2!);
    }
    String msgKeyHash =
        await rust_nostr.generateMessageKeyHash(seedKey: enResult.$3);

    List<String>? toAddPubkeys;

    // listen and sub new receive address
    if (myReceiverAddr != null) {
      toAddPubkeys = await ContactService()
          .addReceiveKey(room.identityId, room.toMainPubkey, myReceiverAddr);

      Get.find<WebsocketService>().listenPubkey(toAddPubkeys,
          since: DateTime.now().subtract(const Duration(seconds: 5)));
      if (!room.isMute) NotifyService.addPubkeys(toAddPubkeys);
    }

    var senderKey = await rust_nostr.generateSimple();

    SendMessageResponse smr = await NostrAPI().sendNip4Message(
        to, base64.encode(ciphertext),
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

  Future<String> _getSignalToAddress(
      KeychatIdentityKeyPair keyPair, Room room) async {
    rust_signal.KeychatSignalSession? bobSession = await rust_signal.getSession(
        keyPair: keyPair,
        address: room.curve25519PkHex!,
        deviceId: room.identityId.toString());

    String to = bobSession!.bobAddress ?? bobSession.address;

    if (to.startsWith('05')) {
      to = room.toMainPubkey;
    } else {
      to = await rust_nostr.generateSeedFromRatchetkeyPair(seedKey: to);
    }

    bool isSendToOnetimeKey =
        to == room.toMainPubkey && room.onetimekey != null;
    if (isSendToOnetimeKey) {
      to = room.onetimekey!;
    }

    return to;
  }

  Future<String> decryptMessage(Room room, NostrEventModel event, Relay relay,
      {NostrEventModel? sourceEvent,
      required Function(String error) failedCallback}) async {
    String? decodeString;
    String? msgKeyHash;
    try {
      rust_signal.KeychatProtocolAddress? kpa =
          await Get.find<ChatxService>().getRoomKPA(room);
      if (kpa == null) {
        String msg = room.getDebugInfo('signal_session_is_null');
        failedCallback(msg);
        throw Exception(msg);
      }
      try {
        var keypair = await room.getKeyPair();
        Uint8List? plaintext;

        (plaintext, msgKeyHash, _) = await rust_signal.decryptSignal(
            keyPair: keypair,
            ciphertext: Uint8List.fromList(base64Decode(event.content)),
            remoteAddress: kpa,
            roomId: room.id,
            isPrekey: false);
        decodeString = utf8.decode(plaintext);
        await setRoomSignalDecodeStatus(room, false);
      } catch (e, s) {
        String msg = Utils.getErrorMessage(e);
        if (msg != ErrorMessages.signalDecryptError) {
          logger.e(msg, error: e, stackTrace: s);
        } else {
          loggerNoLine.e(msg);
        }
        decodeString = "Decrypt failed: $msg, \nSource: ${event.content}";
      }

      // get encrypt msg key's hash
      if (msgKeyHash != null) {
        msgKeyHash =
            await rust_nostr.generateMessageKeyHash(seedKey: msgKeyHash);
        ContactService().deleteReceiveKey(
            room.identityId, room.toMainPubkey, event.tags[0][1]);
      }
      // if receive address is signalAddress, then remove room.onetimekey
      if (room.onetimekey != null) {
        String toAddress = (sourceEvent ?? event).tags[0][1];
        if (toAddress != room.toMainPubkey && toAddress != room.onetimekey!) {
          room.onetimekey = null;
          await RoomService().updateRoom(room);
        }
      }
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
      if (e is AnyhowException) {
        await setRoomSignalDecodeStatus(room, true);
      }
      failedCallback('Signal decrypt failed ${e.toString()}');
      decodeString = "decrypt failed: ${e.toString()}";
    }

    Map<String, dynamic> decodedContent;
    KeychatMessage? km;
    try {
      decodedContent = jsonDecode(decodeString);
      km = KeychatMessage.fromJson(decodedContent);
    } catch (e) {}

    if (km != null) {
      await km.service.proccessMessage(
          room: room,
          event: event,
          km: km,
          fromIdPubkey: room.toMainPubkey,
          msgKeyHash: msgKeyHash,
          sourceEvent: sourceEvent);
      return decodeString;
    }
    await RoomService().receiveDM(room, event,
        decodedContent: decodeString,
        sourceEvent: sourceEvent,
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
  proccessMessage(
      {required Room room,
      required NostrEventModel event,
      required KeychatMessage km,
      NostrEventModel? sourceEvent,
      Function(String error)? failedCallback,
      String? fromIdPubkey,
      String? msgKeyHash}) async {
    switch (km.type) {
      case KeyChatEventKinds.dm: // commom chat, may be contain: reply
        await RoomService().receiveDM(room, event,
            sourceEvent: sourceEvent, km: km, msgKeyHash: msgKeyHash);
        break;
      case KeyChatEventKinds.dmAddContactFromAlice:
      case KeyChatEventKinds.dmAddContactFromBob:
        await _processHelloMessage(room, event, km, sourceEvent);
        break;
      case KeyChatEventKinds.dmReject:
        await _processReject(room, event, km, sourceEvent);
        break;
      case KeyChatEventKinds.signalRelaySyncInvite:
        await _processRelaySyncMessage(room, event, km, sourceEvent);
        break;
      default:
    }
  }

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
    } else {
      room.status = oneTimeKey != null
          ? RoomStatus.approvingNoResponse
          : RoomStatus.approving;
    }
    // use onetime key to response
    if (keychatMessage.type == KeyChatEventKinds.dmAddContactFromAlice) {
      room.onetimekey = model.onetimekey;
    }
    // delete old session
    if (room.curve25519PkHex != null) {
      await Get.find<ChatxService>().deleteSignalSessionKPA(room);
    }
    // must be delete session then give a new data
    room.curve25519PkHex = model.curve25519PkHex;

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
      room.encryptMode = EncryptMode.signal;
    }
    room.contact = contact;
    room = await RoomService().updateRoom(room);

    await RoomService().receiveDM(room, event,
        sourceEvent: sourceEvent,
        km: keychatMessage,
        decodedContent: keychatMessage.toString(),
        realMessage: keychatMessage.msg);

    // auto response
    if (room.status == RoomStatus.enabled &&
        keychatMessage.type == KeyChatEventKinds.dmAddContactFromAlice) {
      String displayName = room.getIdentity().displayName;

      await SignalChatService()
          .sendMessage(room, RoomUtil.getHelloMessage(displayName));
    }
    RoomService().updateChatRoomPage(room);
  }

  Future _processRelaySyncMessage(Room room, NostrEventModel event,
      KeychatMessage keychatMessage, NostrEventModel? sourceEvent) async {
    await RoomService().receiveDM(room, event,
        realMessage: keychatMessage.msg,
        decodedContent: keychatMessage.name,
        mediaType: MessageMediaType.setPostOffice,
        requestConfrim: RequestConfrimEnum.request);
  }

  Future sendRelaySyncMessage(Room room, List<String> relays) async {
    KeychatMessage sm = KeychatMessage(
        c: MessageType.signal,
        type: KeyChatEventKinds.signalRelaySyncInvite,
        name: jsonEncode(relays),
        msg: relays.length == 1
            ? 'My receiving relay is:${relays[0]}'
            : '''My receiving relays are:
${relays.join('\n')}
''');

    await RoomService()
        .sendTextMessage(room, sm.toString(), realMessage: sm.msg);
  }

  Future sendHelloMessage(Room room, Identity identity,
      {int type = KeyChatEventKinds.dmAddContactFromAlice,
      String? onetimekey,
      String? greeting}) async {
    SignalId signalId =
        await SignalIdService.instance.createSignalId(identity.id);
    // after reset session, the room signal key need update
    room.signalIdPubkey = signalId.pubkey;
    room = await RoomService().updateRoom(room);
    KeychatMessage sm = await KeychatMessage(c: MessageType.signal, type: type)
        .setHelloMessagge(signalId: signalId, identity, greeting: greeting);
    await Nip4ChatService().sendIncognitoNip4Message(
      room,
      sm.toString(),
      toAddress: onetimekey,
      realMessage: sm.msg,
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
    await RoomService().receiveDM(room, event,
        sourceEvent: sourceEvent,
        km: km,
        decodedContent: km.toString(),
        realMessage: 'Rejected');

    await RoomService().updateRoom(room);
    RoomService().updateChatRoomPage(room);
    await Get.find<HomeController>().loadIdentityRoomList(room.identityId);
  }

  // decrypt the first signal message
  Future decryptPreKeyMessage(String to, Mykey mykey,
      {required NostrEventModel event,
      required Relay relay,
      required Function(String error) failedCallback}) async {
    var ciphertext = Uint8List.fromList(base64Decode(event.content));
    var prekey = await rust_signal.parseIdentityFromPrekeySignalMessage(
        ciphertext: ciphertext);
    String signalIdPubkey = prekey.$1;
    SignalId? signalId =
        await SignalIdService.instance.getSignalIdByKeyId(prekey.$2);
    if (signalId == null) {
      String msg = 'SignalId not found, identityId: ${mykey.identityId}.';
      if (mykey.roomId != null) {
        Room? room = await RoomService().getRoomById(mykey.roomId!);
        if (room != null) {
          msg = room.getDebugInfo(msg);
        }
      }
      throw Exception(msg);
    }
    KeychatIdentityKeyPair keyPair = await Get.find<ChatxService>()
        .setupSignalStoreBySignalId(signalId.pubkey, signalId);
    Identity identity =
        Get.find<HomeController>().identities[signalId.identityId]!;

    await rust_signal.initKeypair(keyPair: keyPair, regId: 0);
    var (plaintext, msgKeyHash, _) = await rust_signal.decryptSignal(
        keyPair: keyPair,
        ciphertext: ciphertext,
        remoteAddress:
            KeychatProtocolAddress(name: signalIdPubkey, deviceId: identity.id),
        roomId: 0,
        isPrekey: true);
    String decryptedContent = utf8.decode(plaintext);
    PrekeyMessageModel prekeyMessageModel =
        PrekeyMessageModel.fromJson(jsonDecode(decryptedContent));
    logger.i(
        'decryptPreKeyMessage, plainrtext: $prekeyMessageModel, msgKeyHash: $msgKeyHash');

    await SignalChatUtil.verifyPrekeyMessage(
        prekeyMessageModel, identity.secp256k1PKHex);

    Room? room = await RoomService()
        .getRoomByIdentity(prekeyMessageModel.nostrId, identity.id);
    room ??= await RoomService().createPrivateRoom(
        toMainPubkey: prekeyMessageModel.nostrId,
        identity: identity,
        name: prekeyMessageModel.name,
        status: RoomStatus.enabled,
        encryptMode: EncryptMode.signal,
        curve25519PkHex: signalIdPubkey,
        signalId: signalId);

    room.status = RoomStatus.enabled;
    room.encryptMode = EncryptMode.signal;
    room.curve25519PkHex = signalIdPubkey;
    await ContactService().updateContact(
        identityId: room.identityId,
        pubkey: room.toMainPubkey,
        name: prekeyMessageModel.name);
    await RoomService().updateRoom(room);
    await RoomService().updateChatRoomPage(room);
    await Get.find<HomeController>().loadIdentityRoomList(room.identityId);

    KeychatMessage? km;
    try {
      km = KeychatMessage.fromJson(jsonDecode(prekeyMessageModel.message));
    } catch (e) {}
    if (km != null) {
      await km.service.proccessMessage(
          room: room,
          event: event,
          km: km,
          msgKeyHash: msgKeyHash,
          fromIdPubkey: room.toMainPubkey,
          sourceEvent: null,
          failedCallback: failedCallback);
      return;
    }
    await RoomService().receiveDM(room, event,
        sourceEvent: null, decodedContent: prekeyMessageModel.message);
  }
}
