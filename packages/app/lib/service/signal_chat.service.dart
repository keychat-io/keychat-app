import 'dart:async';
import 'dart:convert' show base64, base64Decode, jsonDecode, jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:app/constants.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/service/chat.service.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/service/signal_chat_util.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:convert/convert.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;
import 'package:keychat_rust_ffi_plugin/api_signal.dart';
import 'package:keychat_rust_ffi_plugin/index.dart' show AnyhowException;

class SignalChatService extends BaseChatService {
  // Avoid self instance
  SignalChatService._();
  static SignalChatService? _instance;
  static SignalChatService get instance => _instance ??= SignalChatService._();

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
    final cs = Get.find<ChatxService>();
    final kpa = await cs.getRoomKPA(room);
    if (kpa == null) {
      throw Exception('signal_session_is_null');
    }
    final message0 = message;
    final keypair = await room.getKeyPair();
    final to = await _getSignalToAddress(keypair, room);
    PrekeyMessageModel? pmm;
    if (room.onetimekey != null) {
      if (to == room.onetimekey) {
        final si = room.getMySignalId();
        pmm = await SignalChatUtil.getSignalPrekeyMessage(
          room: room,
          message: message,
          signalPubkey: si?.pubkey ?? '',
        );
      }
    }

    final enResult = await rust_signal.encryptSignal(
      keyPair: keypair,
      ptext: pmm?.toString() ?? message0,
      remoteAddress: kpa,
    );
    final ciphertext = enResult.$1;
    String? newReceving;
    if (enResult.$2 != null) {
      newReceving = await rust_nostr.generateSeedFromRatchetkeyPair(
        seedKey: enResult.$2!,
      );
    }
    final msgKeyHash = await rust_nostr.generateMessageKeyHash(
      seedKey: enResult.$3,
    );

    List<String>? toAddPubkeys;

    // listen and sub new receive address
    if (newReceving != null) {
      toAddPubkeys = await ContactService.instance.addReceiveKey(
        room,
        newReceving,
      );

      Get.find<WebsocketService>().listenPubkey(
        toAddPubkeys,
        since: DateTime.now().subtract(const Duration(seconds: 5)),
        kinds: [EventKinds.nip04],
      );
      if (!room.isMute) unawaited(NotifyService.addPubkeys(toAddPubkeys));
    }

    final senderKey = await rust_nostr.generateSimple();
    final toPubkey = room.type == RoomType.bot ? room.toMainPubkey : to;
    final smr = await NostrAPI.instance.sendEventMessage(
      toPubkey,
      base64.encode(ciphertext),
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
      isEncryptedMessage: true,
      msgKeyHash: msgKeyHash,
      signalReceiveAddress: room.type == RoomType.bot ? to : null,
    );
    smr.toAddPubkeys = toAddPubkeys;
    return smr;
  }

  Future<String> _getSignalToAddress(
    KeychatIdentityKeyPair keyPair,
    Room room,
  ) async {
    final bobSession = await rust_signal.getSession(
      keyPair: keyPair,
      address: room.curve25519PkHex!,
      deviceId: room.identityId.toString(),
    );
    if (bobSession == null) {
      throw Exception('signal_session_is_null');
    }
    var to = bobSession.bobAddress ?? bobSession.address;

    if (to.startsWith('05')) {
      to = room.toMainPubkey;
    } else {
      to = await rust_nostr.generateSeedFromRatchetkeyPair(seedKey: to);
    }

    final isSendToOnetimeKey =
        to == room.toMainPubkey && room.onetimekey != null;
    if (isSendToOnetimeKey) {
      to = room.onetimekey!;
    }

    return to;
  }

  Future<String> decryptMessage(
    Room room,
    NostrEventModel event,
    Relay relay, {
    required void Function(String error) failedCallback,
    NostrEventModel? sourceEvent,
  }) async {
    String? decodeString;
    String? msgKeyHash;
    try {
      final kpa = await Get.find<ChatxService>().getRoomKPA(room);
      if (kpa == null) {
        final msg = room.getDebugInfo('signal_session_is_null');
        failedCallback(msg);
        throw Exception(msg);
      }
      try {
        final keypair = await room.getKeyPair();
        Uint8List? plaintext;

        (plaintext, msgKeyHash, _) = await rust_signal.decryptSignal(
          keyPair: keypair,
          ciphertext: Uint8List.fromList(base64Decode(event.content)),
          remoteAddress: kpa,
          roomId: room.id,
          isPrekey: false,
        );
        decodeString = utf8.decode(plaintext);
        await setRoomSignalDecodeStatus(room, false);
      } catch (e, s) {
        final msg = Utils.getErrorMessage(e);
        if (msg != ErrorMessages.signalDecryptError) {
          logger.e(msg, error: e, stackTrace: s);
        } else {
          loggerNoLine.e(msg);
        }
        decodeString = 'Decrypt failed: $msg, \nSource: ${event.content}';
      }

      // get encrypt msg key's hash
      if (msgKeyHash != null) {
        msgKeyHash = await rust_nostr.generateMessageKeyHash(
          seedKey: msgKeyHash,
        );
        unawaited(
          ContactService.instance.deleteReceiveKey(
            room.identityId,
            room.toMainPubkey,
            event.tags[0][1],
          ),
        );
      }
      // if receive address is signalAddress, then remove room.onetimekey
      if (room.onetimekey != null) {
        final toAddress = (sourceEvent ?? event).tags[0][1];
        if (toAddress != room.toMainPubkey && toAddress != room.onetimekey!) {
          room.onetimekey = null;
          await RoomService.instance.updateRoom(room);
        }
      }
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
      if (e is AnyhowException) {
        await setRoomSignalDecodeStatus(room, true);
      }
      failedCallback('Signal decrypt failed $e');
      decodeString = 'decrypt failed: $e';
    }

    Map<String, dynamic> decodedContent;
    KeychatMessage? km;
    try {
      decodedContent = jsonDecode(decodeString) as Map<String, dynamic>;
      km = KeychatMessage.fromJson(decodedContent);
      // ignore: empty_catches
    } catch (e) {}

    if (km != null) {
      await km.service.proccessMessage(
        room: room,
        event: event,
        km: km,
        fromIdPubkey: room.toMainPubkey,
        failedCallback: failedCallback,
        msgKeyHash: msgKeyHash,
        sourceEvent: sourceEvent,
      );
      return decodeString;
    }
    await RoomService.instance.receiveDM(
      room,
      event,
      decodedContent: decodeString,
      sourceEvent: sourceEvent,
      senderPubkey: room.toMainPubkey,
      msgKeyHash: msgKeyHash,
    );
    return decodeString;
  }

  Future<void> setRoomSignalDecodeStatus(
    Room room,
    bool signalDecodeError,
  ) async {
    if (signalDecodeError == room.signalDecodeError) return;

    room.signalDecodeError = signalDecodeError;
    await RoomService.instance.updateRoomAndRefresh(room);
  }

  @override
  Future<void> proccessMessage({
    required Room room,
    required NostrEventModel event,
    required KeychatMessage km,
    NostrEventModel? sourceEvent,
    void Function(String error)? failedCallback,
    String? fromIdPubkey,
    String? msgKeyHash,
  }) async {
    switch (km.type) {
      case KeyChatEventKinds.signalSendProfile:
      case KeyChatEventKinds.dm: // commom chat, may be contain: reply
        await RoomService.instance.receiveDM(
          room,
          event,
          sourceEvent: sourceEvent,
          km: km,
          msgKeyHash: msgKeyHash,
        );
      case KeyChatEventKinds.dmAddContactFromAlice:
        await _processHelloMessage(
          room,
          event,
          km,
          sourceEvent,
          failedCallback,
        );
      case KeyChatEventKinds.dmReject:
        await _processReject(room, event, km, sourceEvent);
      case KeyChatEventKinds.signalRelaySyncInvite:
        await _processRelaySyncMessage(room, event, km, sourceEvent);
      default:
    }
  }

  Future<(List<String>, List<String>)> processListenAddrs(
    String address,
    String mapKey,
  ) async {
    var sourceList = Storage.getStringList(mapKey);

    // null
    if (sourceList.isEmpty) {
      await Storage.setStringList(mapKey, [address]);
      return ([address], <String>[]);
    }
    // equal
    if (sourceList.last == address) return (<String>[], <String>[]);

    // add
    final addList = <String>[address];
    var removeList = <String>[];
    const maxListenAddrs = 3;
    sourceList.add(address);

    // check if need remove
    if (sourceList.length > maxListenAddrs) {
      removeList = sourceList.sublist(0, 1);
      sourceList = sourceList.sublist(1);
    }
    await Storage.setStringList(mapKey, sourceList);
    return (addList, removeList);
  }

  Future<void> _processHelloMessage(
    Room room,
    NostrEventModel event,
    KeychatMessage keychatMessage,
    NostrEventModel? sourceEvent,
    void Function(String error)? failedCallback,
  ) async {
    if (keychatMessage.name == null) {
      logger.i('name is null');
      return;
    }

    final model = QRUserModel.fromJson(jsonDecode(keychatMessage.name!));
    if (room.version > model.time) {
      logger.e("The message's version is too old, skip");
      if (failedCallback != null) {
        failedCallback("The message's version is too old, skip");
      }
      return;
    }
    room.version = model.time;
    Contact? contact;
    try {
      contact = await ContactService.instance.saveContactFromQrCode(
        identityId: room.identityId,
        pubkey: room.toMainPubkey,
        name: model.name,
        avatarRemoteUrl: model.avatar,
        lightning: model.lightning,
        version: model.time,
        download: false,
      );
    } catch (e) {
      logger.e('saveContactFromQrCode $e');
    }

    Get.find<HomeController>().loadIdentityRoomList(room.identityId);

    // auto send response
    final oneTimeKey = await IdentityService.instance.isFromOnetimeKey(
      (sourceEvent ?? event).tags[0][1],
    );

    // expire onetime-key
    if (oneTimeKey != null) {
      oneTimeKey
        ..oneTimeUsed = true
        ..updatedAt = DateTime.now();
      await IdentityService.instance.updateMykey(oneTimeKey);
    }

    if (room.status == RoomStatus.requesting) {
      room.status = RoomStatus.enabled;
    } else if (room.status != RoomStatus.enabled) {
      room.status = oneTimeKey != null
          ? RoomStatus.approvingNoResponse
          : RoomStatus.approving;
    }
    room.onetimekey = model.onetimekey;

    // delete old session
    if (room.curve25519PkHex != null) {
      await Get.find<ChatxService>().deleteSignalSessionKPA(room);
    }
    // must be delete session then give a new data
    room.curve25519PkHex = model.curve25519PkHex;

    final res = await Get.find<ChatxService>().addRoomKPA(
      room: room,
      bobSignedId: model.signedId,
      bobSignedPublic: Uint8List.fromList(hex.decode(model.signedPublic)),
      bobSignedSignature: Uint8List.fromList(
        hex.decode(model.signedSignature),
      ),
      bobPrekeyId: model.prekeyId,
      bobPrekeyPublic: Uint8List.fromList(hex.decode(model.prekeyPubkey)),
    );
    if (res) {
      room.encryptMode = EncryptMode.signal;
      logger.i('addRoomKPA success, set room encryptMode to signal');
    }
    room.contact = contact;
    await RoomService.instance.updateRoomAndRefresh(room, refreshContact: true);

    await RoomService.instance.receiveDM(
      room,
      event,
      sourceEvent: sourceEvent,
      km: keychatMessage,
      decodedContent: keychatMessage.toString(),
      realMessage: keychatMessage.msg,
    );

    // auto response
    if (room.status == RoomStatus.enabled) {
      final displayName = room.getIdentity().displayName;

      await SignalChatService.instance.sendMessage(
        room,
        RoomUtil.getHelloMessage(displayName),
      );
    }
  }

  Future<void> _processRelaySyncMessage(
    Room room,
    NostrEventModel event,
    KeychatMessage keychatMessage,
    NostrEventModel? sourceEvent,
  ) async {
    await RoomService.instance.receiveDM(
      room,
      event,
      realMessage: keychatMessage.msg,
      decodedContent: keychatMessage.name,
      mediaType: MessageMediaType.setPostOffice,
      requestConfrim: RequestConfrimEnum.request,
    );
  }

  Future<void> sendRelaySyncMessage(Room room, List<String> relays) async {
    final sm = KeychatMessage(
      c: MessageType.signal,
      type: KeyChatEventKinds.signalRelaySyncInvite,
      name: jsonEncode(relays),
      msg: relays.length == 1
          ? 'My receiving relay is:${relays[0]}'
          : '''
My receiving relays are:
${relays.join('\n')}
''',
    );

    await RoomService.instance.sendMessage(
      room,
      sm.toString(),
      realMessage: sm.msg,
    );
  }

  Future<void> sendHelloMessage(
    Room room0,
    Identity identity, {
    String? onetimekey,
    String? greeting,
    bool fromNpub = false,
  }) async {
    var room = room0;
    final signalId = await SignalIdService.instance.createSignalId(identity.id);
    // after reset session, the room signal key need update
    room.signalIdPubkey = signalId.pubkey;
    room = await RoomService.instance.updateRoom(room);
    final sm =
        await KeychatMessage(
          c: MessageType.signal,
          type: KeyChatEventKinds.dmAddContactFromAlice,
        ).setHelloMessagge(
          signalId: signalId,
          identity,
          greeting: greeting,
          fromNpub: fromNpub,
        );
    await NostrAPI.instance.sendNip17Message(
      room,
      sm.toString(),
      identity,
      toPubkey: onetimekey,
      realMessage: sm.msg,
      isSystem: true,
    );
  }

  Future<void> _processReject(
    Room room,
    NostrEventModel event,
    KeychatMessage km,
    NostrEventModel? sourceEvent,
  ) async {
    room.status = RoomStatus.rejected;
    await RoomService.instance.receiveDM(
      room,
      event,
      sourceEvent: sourceEvent,
      km: km,
      decodedContent: km.toString(),
      realMessage: 'Rejected',
    );

    await RoomService.instance.updateRoomAndRefresh(room);
    Get.find<HomeController>().loadIdentityRoomList(room.identityId);
  }

  // decrypt the first signal message
  Future<void> decryptPreKeyMessage(
    String to,
    Mykey mykey, {
    required NostrEventModel event,
    required Relay relay,
    required void Function(String error) failedCallback,
  }) async {
    final ciphertext = Uint8List.fromList(base64Decode(event.content));
    final prekey = await rust_signal.parseIdentityFromPrekeySignalMessage(
      ciphertext: ciphertext,
    );
    final signalIdPubkey = prekey.$1;
    final signalId = await SignalIdService.instance.getSignalIdByKeyId(
      prekey.$2,
    );
    if (signalId == null) {
      var msg = 'SignalId not found, identityId: ${mykey.identityId}.';
      if (mykey.roomId != null) {
        final room = await RoomService.instance.getRoomById(mykey.roomId!);
        if (room != null) {
          msg = room.getDebugInfo(msg);
        }
      }
      failedCallback(msg);
      throw Exception(msg);
    }
    final keyPair = await Get.find<ChatxService>().setupSignalStoreBySignalId(
      signalId.pubkey,
      signalId,
    );
    final identity =
        Get.find<HomeController>().allIdentities[signalId.identityId]!;

    final (plaintext, msgKeyHash, _) = await rust_signal.decryptSignal(
      keyPair: keyPair,
      ciphertext: ciphertext,
      remoteAddress: KeychatProtocolAddress(
        name: signalIdPubkey,
        deviceId: identity.id,
      ),
      roomId: 0,
      isPrekey: true,
    );
    final decryptedContent = utf8.decode(plaintext);
    final prekeyMessageModel = PrekeyMessageModel.fromJson(
      jsonDecode(decryptedContent),
    );
    logger.i(
      'decryptPreKeyMessage, plainrtext: $prekeyMessageModel, msgKeyHash: $msgKeyHash',
    );

    await SignalChatUtil.verifySignedMessage(
      pmm: prekeyMessageModel,
      signalIdPubkey: signalIdPubkey,
    );

    var room = await RoomService.instance.getRoomByIdentity(
      prekeyMessageModel.nostrId,
      identity.id,
    );
    Contact? contact;
    try {
      contact = await ContactService.instance.saveContactFromQrCode(
        identityId: identity.id,
        pubkey: prekeyMessageModel.nostrId,
        name: prekeyMessageModel.name,
        avatarRemoteUrl: prekeyMessageModel.avatar,
        lightning: prekeyMessageModel.lightning,
        version: prekeyMessageModel.time,
      );
    } catch (e) {
      logger.e('saveContactFromQrCode $e');
    }

    room ??= await RoomService.instance.createPrivateRoom(
      toMainPubkey: prekeyMessageModel.nostrId,
      identity: identity,
      name: prekeyMessageModel.name,
      status: RoomStatus.enabled,
      encryptMode: EncryptMode.signal,
      curve25519PkHex: signalIdPubkey,
      signalId: signalId,
      contact: contact,
    );

    room
      ..status = RoomStatus.enabled
      ..encryptMode = EncryptMode.signal
      ..curve25519PkHex = signalIdPubkey
      ..contact = contact;

    await RoomService.instance.updateRoomAndRefresh(room, refreshContact: true);
    Get.find<HomeController>().loadIdentityRoomList(room.identityId);

    KeychatMessage? km;
    try {
      km = KeychatMessage.fromJson(jsonDecode(prekeyMessageModel.message));
      // ignore: empty_catches
    } catch (e) {}
    if (km != null) {
      await km.service.proccessMessage(
        room: room,
        event: event,
        km: km,
        msgKeyHash: msgKeyHash,
        fromIdPubkey: room.toMainPubkey,
        failedCallback: failedCallback,
      );
      return;
    }
    await RoomService.instance.receiveDM(
      room,
      event,
      decodedContent: prekeyMessageModel.message,
    );
  }

  Future<Room?> getSignalChatRoomByTo(String to) async {
    final roomId = ContactService.receiveKeyRooms[to];
    if (roomId == null) {
      return RoomService.instance.getRoomByReceiveKey(to);
    }
    return RoomService.instance.getRoomByIdOrFail(roomId);
  }

  Future<void> resetSignalSession(Room room) async {
    EasyThrottle.throttle(
      'ResetSessionStatus',
      const Duration(seconds: 3),
      () async {
        try {
          await Get.find<ChatxService>().deleteSignalSessionKPA(
            room,
          ); // delete old session
          await SignalChatService.instance.sendHelloMessage(
            room,
            room.getIdentity(),
            greeting: 'Reset signal session status',
          );

          EasyLoading.showInfo('Request sent successfully.');
        } catch (e) {
          final msg = Utils.getErrorMessage(e);
          logger.e(msg, error: e);
          EasyLoading.showToast('Failed to send request');
        }
      },
    );
  }
}
