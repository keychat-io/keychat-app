import 'dart:async';
import 'dart:convert' show base64, base64Decode, jsonDecode, jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:convert/convert.dart' show hex;
import 'package:keychat/constants.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/exceptions/signal_session_not_created_exception.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/nostr-core/nostr.dart';
import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/service/chat.service.dart';
import 'package:keychat/service/chatx.service.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/service/signalId.service.dart';
import 'package:keychat/service/signal_chat_util.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;
import 'package:keychat_rust_ffi_plugin/api_signal.dart';
import 'package:keychat_rust_ffi_plugin/api_signal/types.dart'
    show DecryptResult, KeychatIdentityKeyPair, KeychatProtocolAddress;
import 'package:keychat_rust_ffi_plugin/index.dart' show AnyhowException;

class SignalChatService extends BaseChatService {
  // Avoid self instance
  SignalChatService._();
  static SignalChatService? _instance;
  static SignalChatService get instance => _instance ??= SignalChatService._();

  /// Encrypts and sends a message to [room] using the Signal Double Ratchet protocol.
  ///
  /// When a one-time key is pending ([Room.receiveAddress] is set and matches the current
  /// send address), wraps the plaintext in a signed [PrekeyMessageModel] so the recipient
  /// can verify the sender's identity on first contact.
  /// After encryption, any newly derived ratchet receive address is registered with the
  /// WebSocket subscription and (if the room is not muted) the push notification service.
  ///
  /// Returns a [SendMessageResponse] containing the sent event details and any newly
  /// added receive pubkeys that should be monitored.
  ///
  /// Throws [SignalSessionNotCreatedException] if no active Signal session exists for the room.
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
      throw SignalSessionNotCreatedException();
    }
    final message0 = message;
    final keypair = await room.getKeyPair();
    final to = await _resolveDeliveryAddress(keypair, room);
    PrekeyMessageModel? pmm;
    if (room.receiveAddress != null) {
      if (to == room.receiveAddress) {
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
    final ciphertext = enResult.ciphertext;
    String? newReceving;
    if (enResult.receiverAddress != null) {
      newReceving = await rust_nostr.generateSeedFromRatchetkeyPair(
        seedKey: enResult.receiverAddress!,
      );
    }
    final msgKeyHash = await rust_nostr.generateMessageKeyHash(
      seedKey: enResult.messageKeysHash,
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
      if (!room.isMute) {
        unawaited(NotifyService.instance.addPubkeys(toAddPubkeys));
      }
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

  Future<String> _resolveDeliveryAddress(
    KeychatIdentityKeyPair keyPair,
    Room room,
  ) async {
    final bobSession = await rust_signal.getSession(
      keyPair: keyPair,
      address: room.peerSignalIdentityKey!,
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

    final isSendToReceiveAddress =
        to == room.toMainPubkey && room.receiveAddress != null;
    if (isSendToReceiveAddress) {
      to = room.receiveAddress!;
    }

    return to;
  }

  /// Decrypts an incoming Signal-encrypted message for the given [room].
  ///
  /// Attempts symmetric decryption via [rust_signal.decryptSignal]. On failure,
  /// stores an error placeholder in the decoded content so the UI can show a
  /// "decrypt failed" indicator, and sets [Room.signalDecodeError] accordingly.
  ///
  /// After successful decryption, computes the message key hash, removes the consumed
  /// one-time receive key from the contact store, and clears [Room.receiveAddress] if the
  /// message arrived on a ratchet address rather than the primary address.
  ///
  /// The [failedCallback] is invoked with an error description if decryption fails.
  /// Returns the decoded plaintext string (may be an error message string on failure).
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

        final decryptResult = await rust_signal.decryptSignal(
          keyPair: keypair,
          ciphertext: Uint8List.fromList(base64Decode(event.content)),
          remoteAddress: kpa,
          roomId: room.id,
          isPrekey: false,
        );
        decodeString = utf8.decode(decryptResult.plaintext);
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
      // if receive address is signalAddress, then remove room.receiveAddress
      if (room.receiveAddress != null) {
        final toAddress = (sourceEvent ?? event).tags[0][1];
        if (toAddress != room.toMainPubkey && toAddress != room.receiveAddress!) {
          room.receiveAddress = null;
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

    final km = NostrAPI.instance.tryGetKeyChatMessage(decodeString);

    if (km != null) {
      await km.service.processMessage(
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

  /// Updates [Room.signalDecodeError] and persists the change via [RoomService].
  ///
  /// No-op if [signalDecodeError] already matches the current room flag, avoiding
  /// unnecessary database writes and UI refreshes.
  Future<void> setRoomSignalDecodeStatus(
    Room room,
    bool signalDecodeError,
  ) async {
    if (signalDecodeError == room.signalDecodeError) return;

    room.signalDecodeError = signalDecodeError;
    await RoomService.instance.updateRoomAndRefresh(room);
  }

  /// Dispatches a decrypted [KeychatMessage] to the appropriate Signal handler.
  ///
  /// Routes by [km.type]:
  /// - [KeyChatEventKinds.signalSendProfile] / [KeyChatEventKinds.dm]:
  ///   delivers as a regular chat message via [RoomService.receiveDM].
  /// - [KeyChatEventKinds.dmAddContactFromAlice]:
  ///   processes the initial X3DH hello and establishes the Signal session.
  /// - [KeyChatEventKinds.dmReject]:
  ///   marks the room as rejected and records the system event.
  /// - [KeyChatEventKinds.signalRelaySyncInvite]:
  ///   stores the relay sync invitation for user review.
  @override
  Future<void> processMessage({
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

  /// Manages a rolling window of up to 3 listen addresses stored under [mapKey].
  ///
  /// Returns a record `(addList, removeList)`:
  /// - `addList` — new addresses to subscribe to on the WebSocket relay.
  /// - `removeList` — addresses evicted from the window that should be unsubscribed.
  ///
  /// Returns empty lists when [address] is already the most-recently added entry,
  /// avoiding redundant subscription changes.
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

    final model = QRUserModel.fromJson(
      jsonDecode(keychatMessage.name!) as Map<String, dynamic>,
    );
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
    final inboxKey = await IdentityService.instance.findInboxKey(
      (sourceEvent ?? event).tags[0][1],
    );

    // expire inbox key
    if (inboxKey != null) {
      inboxKey
        ..oneTimeUsed = true
        ..updatedAt = DateTime.now();
      await IdentityService.instance.updateMykey(inboxKey);
    }

    if (room.status == RoomStatus.requesting) {
      room.status = RoomStatus.enabled;
    } else if (room.status != RoomStatus.enabled) {
      room.status = inboxKey != null
          ? RoomStatus.approvingNoResponse
          : RoomStatus.approving;
    }
    room.receiveAddress = model.receiveAddress;

    // delete old session
    if (room.peerSignalIdentityKey != null) {
      await Get.find<ChatxService>().deleteSignalSessionKPA(room);
    }
    // must be delete session then give a new data
    room.peerSignalIdentityKey = model.signalIdentityKey;

    final res = await Get.find<ChatxService>().addRoomKPA(
      room: room,
      bobSignedId: model.signalSignedPrekeyId,
      bobSignedPublic: Uint8List.fromList(hex.decode(model.signalSignedPrekey)),
      bobSignedSignature: Uint8List.fromList(
        hex.decode(model.signalSignedPrekeySignature),
      ),
      bobPrekeyId: model.signalOneTimePrekeyId,
      bobPrekeyPublic: Uint8List.fromList(hex.decode(model.signalOneTimePrekey)),
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
      isSystem: true,
    );

    // auto response
    if (room.status == RoomStatus.enabled) {
      final displayName = room.getIdentity().displayName;

      await SignalChatService.instance.sendMessage(
        room,
        RoomUtil.getHelloMessage(displayName),
        isSystem: true,
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

  /// Sends a relay sync invitation to [room], advertising the given [relays].
  ///
  /// The recipient receives a [KeyChatEventKinds.signalRelaySyncInvite] message and
  /// can accept it to update their post-office relay configuration for this contact.
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

  /// Initiates the X3DH key exchange by sending a hello message to [room].
  ///
  /// Creates a fresh [SignalId] for [identity], builds a signed [KeychatMessage]
  /// of type [KeyChatEventKinds.dmAddContactFromAlice], and delivers it via NIP-17.
  ///
  /// [receiveAddress] — optional one-time key pubkey to use as the delivery address.
  /// [greeting] — optional greeting text included in the message body.
  /// [fromNpub] — set to `true` when initiating from an npub / QR-code scan flow.
  Future<void> sendHelloMessage(
    Room room0,
    Identity identity, {
    String? receiveAddress,
    String? greeting,
    bool fromNpub = false,
  }) async {
    var room = room0;
    final signalId = await SignalIdService.instance.createSignalId(identity.id);
    // after reset session, the room signal key need update
    room.mySignalIdentityKey = signalId.pubkey;
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
      toPubkey: receiveAddress,
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

  /// Decrypts an incoming Signal prekey message (first message from a new contact).
  ///
  /// Parses the sender's [KeychatProtocolAddress] from the ciphertext header, locates
  /// the matching [SignalId] by key ID, and decrypts with [rust_signal.decryptSignal].
  /// Creates or updates the [Room] record for the sender, saves the contact profile,
  /// and delivers the inner message payload to [RoomService.receiveDM].
  ///
  /// [to] — the local one-time key address the prekey message was sent to.
  /// [mykey] — the [Mykey] record for the one-time key address.
  /// The [failedCallback] is invoked with an error description on any unrecoverable error.
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
    final peerSignalKey = prekey.identityKey;
    final signalId = await SignalIdService.instance.getSignalIdByKeyId(
      prekey.signedPreKeyId,
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

    final decryptResult = await rust_signal.decryptSignal(
      keyPair: keyPair,
      ciphertext: ciphertext,
      remoteAddress: KeychatProtocolAddress(
        name: peerSignalKey,
        deviceId: identity.id,
      ),
      roomId: 0,
      isPrekey: true,
    );
    final decryptedContent = utf8.decode(decryptResult.plaintext);
    final prekeyMessageModel = PrekeyMessageModel.fromJson(
      jsonDecode(decryptedContent) as Map<String, dynamic>,
    );
    logger.i('decryptPreKeyMessage, plainrtext: $prekeyMessageModel');

    await SignalChatUtil.verifySignedMessage(
      pmm: prekeyMessageModel,
      signalIdPubkey: peerSignalKey,
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
      peerSignalIdentityKey: peerSignalKey,
      signalId: signalId,
      contact: contact,
    );

    room
      ..status = RoomStatus.enabled
      ..encryptMode = EncryptMode.signal
      ..peerSignalIdentityKey = peerSignalKey
      ..contact = contact;

    await RoomService.instance.updateRoomAndRefresh(room, refreshContact: true);
    Get.find<HomeController>().loadIdentityRoomList(room.identityId);

    KeychatMessage? km;
    try {
      km = KeychatMessage.fromJson(
        jsonDecode(prekeyMessageModel.message) as Map<String, dynamic>,
      );
      // ignore: empty_catches
    } catch (e) {}
    if (km != null) {
      await km.service.processMessage(
        room: room,
        event: event,
        km: km,
        msgKeyHash: decryptResult.messageKeysHash,
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

  /// Returns the [Room] associated with the given Signal receive address [to].
  ///
  /// First checks the in-memory [ContactService.receiveKeyRooms] cache for a fast
  /// lookup, then falls back to a database query via [RoomService.getRoomByReceiveKey].
  Future<Room?> getSignalChatRoomByTo(String to) async {
    final roomId = ContactService.receiveKeyRooms[to];
    if (roomId == null) {
      return RoomService.instance.getRoomByReceiveKey(to);
    }
    return RoomService.instance.getRoomByIdOrFail(roomId);
  }

  /// Resets the Signal session for [room] by deleting stale session state and
  /// re-initiating the X3DH handshake with a new hello message.
  ///
  /// Throttled to at most once per 3 seconds to prevent duplicate reset storms.
  /// Shows a success info toast on completion, or an error toast on failure.
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
          final updatedRoom = await RoomService.instance.getRoomByIdOrFail(
            room.id,
          );
          if (updatedRoom.status == RoomStatus.approving) {
            updatedRoom.status = RoomStatus.requesting;
          }
          await RoomService.instance.updateRoomAndRefresh(updatedRoom);
          await EasyLoading.showInfo('Request sent successfully.');
        } catch (e) {
          final msg = Utils.getErrorMessage(e);
          logger.e(msg, error: e);
          await EasyLoading.showToast('Failed to send request');
        }
      },
    );
  }
}
