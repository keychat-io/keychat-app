# Signal Protocol — 1:1 Chat

## Overview

Keychat uses the Signal Protocol (Double Ratchet + X3DH) for end-to-end encrypted 1:1
direct messaging. The Dart service layer (`SignalChatService`) wraps a Rust
implementation via Flutter FFI (`keychat_rust_ffi_plugin/api_signal`). Nostr relays serve
as the transport layer; messages are published as NIP-04 events (kind 4) or wrapped in
NIP-17 gift-wraps (kind 1059).

### Key Properties

- **Forward secrecy** — each message is encrypted under a unique ratchet-derived key.
  Compromising one key does not expose past messages.
- **Post-compromise security** — after a key exchange, a previously compromised session
  cannot decrypt future messages.
- **Sender anonymity** — outbound messages use an ephemeral Nostr keypair generated per
  message (`rust_nostr.generateSimple()`), so the real identity pubkey is never the
  Nostr event author.
- **Rotating receive addresses** — the Signal ratchet periodically generates a new
  Nostr pubkey that becomes the receive address for the next message. Up to 3 past
  receive addresses are retained simultaneously.

---

## Message Flow

### Session Establishment (X3DH)

The Signal session must be bootstrapped before any encrypted message can be sent. This
is done via a "hello message":

```
Alice (initiator)                              Bob (responder)
  |                                               |
  |-- SignalIdService.createSignalId() ---------->| (local: generate identity key + prekeys)
  |
  |-- sendHelloMessage(room, identity) ---------->| NIP-17 kind 1059
  |     |-- KeychatMessage {                      |   (unencrypted Signal prekey bundle)
  |     |     type: dmAddContactFromAlice,        |
  |     |     payload: QRUserModel {              |
  |     |       curve25519PkHex,                  |
  |     |       signedId, signedPublic,           |
  |     |       signedSignature,                  |
  |     |       prekeyId, prekeyPubkey,           |
  |     |       sig (Schnorr over nostrId+signalId+time)
  |     |     }                                   |
  |     |   }                                     |
  |                                               |
  |                            Bob._processHelloMessage()
  |                              |-- verify Schnorr sig
  |                              |-- ChatxService.addRoomKPA() [X3DH import]
  |                              |-- room.encryptMode = signal
  |                              |-- auto-reply sendHelloMessage → Alice
  |
  |<-- hello reply (pairwise Signal session now active) -------|
```

**Key exchange material in `QRUserModel`:**

| Field               | Description                                         |
|---------------------|-----------------------------------------------------|
| `curve25519PkHex`   | Alice's Signal identity public key (Curve25519)     |
| `signedId`          | ID of Alice's signed prekey                         |
| `signedPublic`      | Alice's signed prekey public key                    |
| `signedSignature`   | Signature over the signed prekey                    |
| `prekeyId`          | ID of Alice's one-time prekey                       |
| `prekeyPubkey`      | Alice's one-time prekey public key                  |
| `sig`               | Schnorr signature: `sign(nostrId + signalId + time)`|
| `onetimekey`        | Optional Nostr one-time key (for anonymous contact) |

### Sending a Message (after session established)

```
Sender
  |
  |-- cs.getRoomKPA(room)              ← retrieve prekey address for session
  |-- room.getKeyPair()                ← load Signal keypair
  |-- _getSignalToAddress(keypair, room)
  |     |-- rust_signal.getSession()   ← look up Bob's current ratchet address
  |     |-- map to Nostr pubkey (via rust_nostr.generateSeedFromRatchetkeyPair)
  |     |-- if onetimekey present → use onetimekey as destination
  |
  |-- [optional] SignalChatUtil.getSignalPrekeyMessage()
  |     (wraps message in PrekeyMessageModel with Schnorr sig — for first message after session reset)
  |
  |-- rust_signal.encryptSignal(keyPair, plaintext, remoteAddress)
  |     └── returns (ciphertext, newRatchetKeyHex?, msgKeyHashSeed)
  |
  |-- [if newRatchetKeyHex] rust_nostr.generateSeedFromRatchetkeyPair()
  |     └── derive new receive Nostr pubkey → ContactService.addReceiveKey()
  |     └── WebsocketService.listenPubkey() on new address
  |
  |-- rust_nostr.generateMessageKeyHash(seedKey)  ← derive dedup/audit hash
  |-- rust_nostr.generateSimple()                 ← ephemeral sender keypair
  |-- NostrAPI.sendEventMessage(toPubkey, base64(ciphertext), encryptType: signal)
```

### Receiving a Message (regular Signal message)

```
Nostr relay → WebSocket → kind 4 or kind 1059 event
  |
  |-- SignalChatService.decryptMessage(room, event, relay)
  |     |-- cs.getRoomKPA(room)           ← get session prekey address
  |     |-- room.getKeyPair()             ← load Signal keypair
  |     |-- rust_signal.decryptSignal(keyPair, ciphertext, remoteAddress, isPrekey=false)
  |     |     └── returns (plaintext, msgKeyHashSeed?, _)
  |     |-- rust_nostr.generateMessageKeyHash()   ← compute dedup hash
  |     |-- ContactService.deleteReceiveKey()     ← mark old receive address consumed
  |     |-- [if onetimekey != destination] clear room.onetimekey
  |     |
  |     |-- NostrAPI.tryGetKeyChatMessage(plaintext)
  |           |-- [if KeychatMessage] → SignalChatService.proccessMessage()
  |           |-- [else]             → RoomService.receiveDM()
```

### Receiving the First Message (PreKey Message / X3DH)

```
Nostr relay → event arrives on Bob's one-time Nostr key
  |
  |-- SignalChatService.decryptPreKeyMessage(to, mykey, event, relay)
  |     |-- rust_signal.parseIdentityFromPrekeySignalMessage(ciphertext)
  |     |     └── returns (signalIdPubkey, signalKeyId)
  |     |-- SignalIdService.getSignalIdByKeyId(signalKeyId)
  |     |-- ChatxService.setupSignalStoreBySignalId()
  |     |-- rust_signal.decryptSignal(..., isPrekey=true)
  |     |-- SignalChatUtil.verifySignedMessage()   ← verify Schnorr sig
  |     |-- RoomService.createPrivateRoom() or update existing room
  |     |-- dispatch to proccessMessage() or receiveDM()
```

---

## Key Data Structures

### Room (Signal-relevant fields)

| Field               | Type              | Description                                           |
|---------------------|-------------------|-------------------------------------------------------|
| `curve25519PkHex`   | `String?`         | Peer's Signal identity public key                     |
| `signalIdPubkey`    | `String?`         | Our Signal identity pubkey used in this session       |
| `onetimekey`        | `String?`         | Destination one-time Nostr key for next message       |
| `encryptMode`       | `EncryptMode`     | `signal` when Signal session is active                |
| `signalDecodeError` | `bool`            | True if the last decryption failed                    |
| `status`            | `RoomStatus`      | Session lifecycle state (see below)                   |
| `version`           | `int`             | Timestamp used to reject replayed hello messages      |

### RoomStatus Lifecycle

```
requesting → approving → enabled
                       ↘ approvingNoResponse (arrived via one-time key, no reply yet)
                       ↘ rejected
                       ↘ disabled
```

| Status                | Meaning                                                  |
|-----------------------|----------------------------------------------------------|
| `requesting`          | Hello sent, waiting for peer's response                  |
| `approving`           | Hello received from peer, awaiting user acceptance       |
| `approvingNoResponse` | Hello received via one-time key; no auto-response sent   |
| `enabled`             | Bidirectional Signal session established                 |
| `rejected`            | Peer explicitly rejected the contact request             |

### SignalId

| Field          | Type      | Description                                        |
|----------------|-----------|----------------------------------------------------|
| `pubkey`       | `String`  | Curve25519 public key (hex)                        |
| `prikey`       | `String`  | Curve25519 private key (hex)                       |
| `identityId`   | `int`     | Owning Nostr identity                              |
| `signalKeyId`  | `int?`    | Signed prekey ID registered with Signal store      |
| `keys`         | `String?` | JSON blob: signedId, signedPublic, prekeyId, etc.  |
| `isUsed`       | `bool`    | True after the Signal session uses this ID         |
| `isGroupSharedKey` | `bool` | True when shared across a Signal group session  |

### PrekeyMessageModel

Used as the plaintext payload in the very first Signal message (PreKeySignalMessage):

| Field          | Description                                            |
|----------------|--------------------------------------------------------|
| `nostrId`      | Sender's secp256k1 Nostr pubkey                        |
| `signalId`     | Sender's Curve25519 Signal pubkey                      |
| `time`         | Unix timestamp (replay protection)                     |
| `name`         | Sender's display name                                  |
| `sig`          | Schnorr signature over `Keychat-{nostrId}-{signalId}-{time}` |
| `message`      | The actual chat message content                        |
| `lightning`    | Optional Lightning address                             |
| `avatar`       | Optional avatar URL                                    |

---

## API Reference

### SignalChatService

| Method | Description |
|--------|-------------|
| `sendMessage(room, message, ...)` | Encrypt and send a Signal message; rotates receive key if ratchet advances |
| `decryptMessage(room, event, relay, ...)` | Decrypt an incoming Signal message |
| `decryptPreKeyMessage(to, mykey, event, relay, ...)` | Decrypt the very first message (X3DH bootstrap) |
| `sendHelloMessage(room, identity, ...)` | Send Signal prekey bundle to initiate/reset session |
| `resetSignalSession(room)` | Delete local session and resend hello (throttled 3 s) |
| `sendRelaySyncMessage(room, relays)` | Share preferred receiving relay list with peer |
| `setRoomSignalDecodeStatus(room, bool)` | Update `room.signalDecodeError` flag |
| `getSignalChatRoomByTo(to)` | Resolve a receive-key address to its Room |
| `processListenAddrs(address, mapKey)` | Manage the rolling window of up to 3 receive addresses |
| `proccessMessage(room, event, km, ...)` | Dispatch an already-decrypted KeychatMessage by type |

### SignalIdService

| Method | Description |
|--------|-------------|
| `createSignalId(identityId, [isGroupSharedKey])` | Generate a new Signal identity with signed prekey + one-time prekey |
| `isFromSignalId(toAddress)` | Look up a SignalId by pubkey (for incoming-message routing) |
| `getSignalIdByKeyId(signalKeyId)` | Look up a SignalId by signed-prekey ID |
| `getSignalIdByPubkey(pubkey)` | Look up a SignalId by pubkey |
| `getSignalIdByIdentity(identityId)` | Get all unused SignalIds for an identity |
| `importOrGetSignalId(identityId, roomProfile)` | Import a shared Signal identity from a group room profile |
| `deleteExpiredSignalIds()` | Purge used SignalIds older than `KeychatGlobal.signalIdLifetime` hours |
| `getQRCodeData(signalId, time)` | Produce the QR-code key material dict for sharing |

### SignalChatUtil

| Method | Description |
|--------|-------------|
| `getSignalPrekeyMessage(room, message, signalPubkey)` | Build a signed `PrekeyMessageModel` for session-reset messages |
| `verifySignedMessage(pmm, signalIdPubkey)` | Verify the Schnorr binding signature on an incoming prekey message |
| `signByIdentity(identity, content, [id])` | Sign content with the identity's secp256k1 key (or external signer) |
| `getToSignMessage(nostrId, signalId, time)` | Construct the canonical string to sign: `Keychat-{nostrId}-{signalId}-{time}` |
| `getPrekeySigContent(ids)` | Sort and join pubkeys for multi-party prekey signature content |

---

## Integration Guide

### Initiating a Chat

```dart
// After scanning a contact's QR code or receiving their npub:
await SignalChatService.instance.sendHelloMessage(
  room,
  identity,
  onetimekey: contact.onetimekey, // optional, for anonymous contact
  greeting: 'Hello!',
);
// room.status becomes RoomStatus.requesting
```

### Sending Messages

```dart
// Standard send — handles encryption and ratchet advancement automatically:
await RoomService.instance.sendMessage(room, 'Hello!');

// Internally routes to:
await SignalChatService.instance.sendMessage(room, 'Hello!');
```

### Resetting a Broken Session

```dart
// Use when decryption fails repeatedly (room.signalDecodeError == true):
await SignalChatService.instance.resetSignalSession(room);
// Throttled to once per 3 seconds.
```

### Handling Incoming Events

All routing is handled by `WebsocketService` → `ChatService`. The UI does not need to
call `decryptMessage` directly. Listen to room state via GetX:

```dart
final room = Get.find<RoomController>().roomObs.value;
// room.signalDecodeError — show warning banner if true
// room.status — show appropriate UI state
```

---

## Known Limitations

### Receive Address Window

The rolling receive-address window is capped at 3 addresses (`maxListenAddrs = 3`).
If the sender advances the ratchet more than 3 steps without the receiver processing
any messages (e.g., the receiver is offline for an extended period), older messages
may be unroutable.

### Session Reset Requires Connectivity

`resetSignalSession` sends a new hello message over the network. If the peer is
unreachable, the session remains broken until the peer comes back online and processes
the hello.

### One-Time Prekeys Not Replenished Automatically

`SignalId` records are created on demand (per-session or per-group-join) and deleted
after `KeychatGlobal.signalIdLifetime` hours. There is no automatic background job that
pre-generates a pool of prekeys and publishes them to relays (unlike the libsignal
server model). This is by design for the decentralized Nostr transport, but means
that contacts cannot initiate a new session while the user is offline for a long time.

### No Multi-Device Support

A Signal session is bound to a single `identityId` + `curve25519PkHex` pair. Messages
sent to one device are not delivered to another device using the same Nostr identity.
Multi-device support would require a Sealed Sender or multi-device prekey distribution
mechanism not currently implemented.
