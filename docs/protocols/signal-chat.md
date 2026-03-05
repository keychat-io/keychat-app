# Signal Protocol — Private Chat

## Overview

Keychat implements the Signal Protocol for end-to-end encrypted one-to-one messaging.
The Signal Protocol combines the **X3DH** (Extended Triple Diffie-Hellman) key agreement
for session establishment with the **Double Ratchet** algorithm for ongoing message
encryption, providing both forward secrecy and break-in recovery.

Messages are delivered over the **Nostr** network (NIP-04 encrypted DM events, kind 4)
using ephemeral sender keypairs to prevent correlation. The Signal session state is
managed by the Rust FFI layer (`api_signal.dart` / `api_signal.rs`).

**Key source files:**
- `packages/app/lib/service/signal_chat.service.dart` — main send/receive logic
- `packages/app/lib/service/signal_chat_util.dart` — signing utilities
- `packages/app/lib/service/signalId.service.dart` — Signal identity key management

---

## Message Flow

### 1. Session Establishment (X3DH Hello)

```
Alice                                           Bob
  |                                               |
  |-- createSignalId() ----------------------->  |
  |   (generate Curve25519 identity key + prekey bundle)
  |                                               |
  |-- sendHelloMessage() ----------------------> |
  |   NIP-17 message containing:                 |
  |   - KeychatMessage { type: dmAddContactFromAlice }
  |   - PrekeyMessageModel {                      |
  |       nostrId, signalId, time,                |
  |       signedId, signedPublic, signedSignature,|
  |       prekeyId, prekeyPubkey,                 |
  |       sig (Schnorr over nostrId+signalId+time)|
  |     }                                         |
  |                                               |
  |                          decryptPreKeyMessage()|
  |                          verifySignedMessage() |
  |                          addRoomKPA()          |
  |                          (session established) |
  |                                               |
  |                    <-- sendMessage() ---------|
  |                       (first Signal-encrypted |
  |                        response message)       |
```

### 2. Ongoing Messaging (Double Ratchet)

```
Sender                                         Receiver
  |                                               |
  |-- getRoomKPA() (get protocol address) ------> |
  |-- encryptSignal() (Rust FFI) -------------->  |
  |   ciphertext = base64(encrypted bytes)        |
  |   newReceiving = derived ratchet address      |
  |   msgKeyHash = hash of message key            |
  |                                               |
  |-- sendEventMessage() (NIP-04, kind 4) ------> |
  |   from: ephemeral Nostr keypair               |
  |   to:   ratchet address (or onetimekey)       |
  |                                               |
  |                          decryptMessage()      |
  |                          decryptSignal() (FFI) |
  |                          deleteReceiveKey()    |
  |                          receiveDM()           |
```

### 3. Receive Address Rotation

The Double Ratchet produces a new receive address after each message. Keychat
maintains a rolling window of **3 active receive addresses** per room
(`processListenAddrs`). Old addresses are unsubscribed from the WebSocket relay
as new ones are registered.

---

## Key Data Structures

### SignalId (`packages/app/lib/models/signal_id.dart`)

Represents a Signal identity key pair stored in the Isar database.

| Field | Type | Description |
|-------|------|-------------|
| `pubkey` | `String` | Hex-encoded Curve25519 public key (used as Nostr address) |
| `prikey` | `String` | Hex-encoded Curve25519 private key |
| `identityId` | `int` | Owning identity (FK to `Mykey.identityId`) |
| `signalKeyId` | `int` | Signed prekey ID registered in the Signal store |
| `keys` | `String?` | JSON blob with `signedId/Public/Signature` and `prekeyId/Pubkey`; includes `signedRecord/prekeyRecord` for group shared keys |
| `isGroupSharedKey` | `bool` | Whether this ID is used for Signal-based group shared key |
| `isUsed` | `bool` | Whether this ID has been consumed by a prekey exchange |

### PrekeyMessageModel (`packages/app/lib/models/keychat/prekey_message_model.dart`)

Embedded in the first encrypted Signal message to authenticate the sender's Nostr identity.

| Field | Description |
|-------|-------------|
| `nostrId` | Sender's secp256k1 (Nostr) public key hex |
| `signalId` | Sender's Curve25519 (Signal) public key hex |
| `time` | Unix timestamp (ms) for replay protection |
| `sig` | Schnorr signature over `Keychat-<nostrId>-<signalId>-<time>` |
| `name` | Sender display name |
| `avatar` | Sender avatar remote URL |
| `lightning` | Sender Lightning address |
| `message` | Inner plaintext payload (the actual first message) |

### KeychatProtocolAddress (`keychat_rust_ffi_plugin`)

Maps a Signal session to a specific device/identity.

| Field | Description |
|-------|-------------|
| `name` | Curve25519 public key hex of the remote party |
| `deviceId` | Identity ID (integer) of the local identity |

---

## API Reference

### SignalChatService

| Method | Description |
|--------|-------------|
| `sendMessage(room, message, ...)` | Encrypt and send via Double Ratchet; handles ratchet address rotation |
| `decryptMessage(room, event, relay, ...)` | Decrypt incoming Signal message; handles key hash and address cleanup |
| `decryptPreKeyMessage(to, mykey, ...)` | Decrypt first message from a new contact (X3DH prekey message) |
| `sendHelloMessage(room, identity, ...)` | Initiate X3DH key exchange; called when adding a contact |
| `resetSignalSession(room)` | Delete stale session and re-send hello to recover broken sessions |
| `processListenAddrs(address, mapKey)` | Manage rolling window of 3 ratchet receive addresses |
| `sendRelaySyncMessage(room, relays)` | Advertise post-office relay list to contact |
| `proccessMessage(...)` | Dispatch decrypted KeychatMessage to type-specific handler |
| `setRoomSignalDecodeStatus(room, error)` | Persist Signal decode error flag to room |
| `getSignalChatRoomByTo(to)` | Look up Room by receive address (cache + DB) |

### SignalIdService

| Method | Description |
|--------|-------------|
| `createSignalId(identityId, [isGroupSharedKey])` | Generate + persist a new Signal identity key with signed prekey |
| `getSignalIdByKeyId(signalKeyId)` | Look up SignalId by signed prekey ID (used in prekey decrypt) |
| `getSignalIdByPubkey(pubkey)` | Look up SignalId by public key |
| `getQRCodeData(signalId, time)` | Produce fresh prekey bundle for QR code sharing |
| `importOrGetSignalId(identityId, roomProfile)` | Import group shared key from RoomProfile |
| `deleteExpiredSignalIds()` | Prune consumed keys older than `signalIdLifetime` hours |

### SignalChatUtil

| Method | Description |
|--------|-------------|
| `getToSignMessage(nostrId, signalId, time)` | Canonical string for Schnorr signing |
| `signByIdentity(identity, content, [id])` | Sign with stored key or external signer (NIP-55) |
| `verifySignedMessage(pmm, signalIdPubkey)` | Verify PrekeyMessageModel Schnorr signature |
| `getSignalPrekeyMessage(room, message, signalPubkey)` | Build signed PrekeyMessageModel |

---

## Integration Guide

### Adding a New Contact

```dart
// 1. User scans contact QR code → obtain onetimekey (optional) + nostrId
// 2. Create or retrieve the Room
final room = await RoomService.instance.createPrivateRoom(...);

// 3. Send hello (X3DH)
await SignalChatService.instance.sendHelloMessage(
  room,
  identity,
  onetimekey: scannedOnetimeKey,  // optional
  greeting: 'Hello!',
);
// Room status becomes RoomStatus.requesting
```

### Sending a Message

```dart
await RoomService.instance.sendMessage(room, text);
// Internally calls SignalChatService.sendMessage() which:
//   1. Gets the session protocol address via ChatxService.getRoomKPA()
//   2. Calls rust_signal.encryptSignal()
//   3. Registers new ratchet address if returned
//   4. Sends via NostrAPI.sendEventMessage() with encryptType = signal
```

### Receiving a Message

The WebSocket service delivers Nostr events to `ChatService`, which routes them
based on the destination pubkey:

- If destination matches a one-time key → `decryptPreKeyMessage()`
- If destination matches a known Signal receive address → `decryptMessage()`

### Resetting a Broken Session

```dart
// When decryption fails repeatedly (room.signalDecodeError == true):
await SignalChatService.instance.resetSignalSession(room);
```

---

## Known Limitations / Deprecated Features

### `SignalChatUtil.getPrekeySigContent(List<String> ids)`

**Status:** `DEPRECATED — no callers found after prekey signature format change`

This utility method sorts and joins a list of IDs as a comma-separated string,
originally intended for a multi-ID signature scheme. The current prekey exchange
uses the `Keychat-<nostrId>-<signalId>-<time>` format exclusively. This method
has no callers in the codebase and is a candidate for removal.

### One-Time Key (`Room.onetimekey`) Clearing

The logic for clearing `onetimekey` after the first ratchet message is embedded
in `decryptMessage`. If a peer sends a second message before the first is processed,
the onetimekey may not be cleared in time. This is a known edge case that depends
on Nostr relay delivery ordering.

### Bot Room Signal Routing

When `room.type == RoomType.bot`, the send-to address is forced to
`room.toMainPubkey` while `signalReceiveAddress` is set separately. This is a
workaround for bots that do not perform address rotation and may be revisited
if bot behaviour is formalised.
