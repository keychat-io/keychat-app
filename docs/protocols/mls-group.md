# MLS Protocol — Group Chat

## Overview

Keychat uses the [Message Layer Security (MLS)](https://www.rfc-editor.org/rfc/rfc9420) protocol for encrypted group messaging. MLS provides:

- **Forward secrecy** — compromising a member's key does not expose past messages
- **Post-compromise security** — after key rotation, a compromised key can no longer decrypt future messages
- **Scalable key management** — O(log N) key updates for N members via a ratchet tree

The Dart service layer (`MlsGroupService`) wraps a Rust implementation via Flutter FFI (`keychat_rust_ffi_plugin`). Nostr relays are used as the transport layer for all MLS messages.

### Nostr Event Kinds Used

| Kind  | Name              | Description                                   |
|-------|-------------------|-----------------------------------------------|
| 444   | MLS Welcome       | Encrypted invitation sent to new members      |
| 445   | MLS Message       | Encrypted group messages and commit payloads  |
| 10443 | MLS Key Package   | Public MLS key packages published by users    |

All group messages (kinds 444, 445) are wrapped in NIP-17 (kind 1059 gift-wrap) for metadata privacy.

---

## Group Lifecycle

### Creation

1. **Generate group ID** — a random secp256k1 keypair; the public key is the group's identity (`room.toMainPubkey`).
2. **Initialize MLS group** — call `rust_mls.createMlsGroup` with group name, admin pubkeys, relays, and initial status.
3. **Self-update key** — `_selfUpdateKeyLocal` creates an initial self-update proposal embedding the creator's display name.
4. **Self-commit** — `rust_mls.selfCommit` commits the initial epoch.
5. **Add initial members** — `rust_mls.addMembers` produces a Welcome blob and queued commit message.
6. **Self-commit again** — the add commit is finalized.
7. **Set listening key** — `replaceListenPubkey` derives the group subscription key from the MLS export secret and subscribes the WebSocket.
8. **Send Welcome messages** — `_sendInviteMessage` sends the base64-encoded Welcome to each invited member via NIP-17 kind 444.

```
Creator
  │
  ├── rust_mls.createMlsGroup()
  ├── rust_mls.selfCommit()            ← epoch 0
  ├── rust_mls.addMembers(keyPackages) ← produces Welcome + commit
  ├── rust_mls.selfCommit()            ← epoch 1
  ├── replaceListenPubkey()            ← derive new subscription key
  └── _sendInviteMessage()             ← NIP-17 kind 444 to each invitee
```

### Member Addition

1. **Validate key packages** — `checkPkIsValid` verifies each invitee's key package has not expired.
2. **Check existing members** — `existExpiredMember` throws if any current member has an expired key package.
3. **Add members** — `rust_mls.addMembers` produces a commit + Welcome blob.
4. **Broadcast commit** — `sendEncryptedMessage` sends the commit to the group's one-time key (kind 445).
5. **Self-commit** — `rust_mls.selfCommit` finalizes the epoch transition.
6. **Rotate listening key** — `replaceListenPubkey` subscribes to the new epoch key.
7. **Send Welcome** — `_sendInviteMessage` sends kind 444 invitations to the new members.

### Member Removal

1. **Wait for EOSE** — `waitingForEose` ensures all pending messages are processed first.
2. **Get leaf indices** — `rust_mls.getLeadNodeIndex` looks up each member's position in the ratchet tree.
3. **Remove members** — `rust_mls.removeMembers` produces a remove commit.
4. **Broadcast commit** — `sendEncryptedMessage` sends the commit to all remaining members.
5. **Self-commit** — `rust_mls.selfCommit` finalizes the removal.
6. **Rotate listening key** — `replaceListenPubkey` updates the subscription key.

### Voluntary Leave

A member wishing to leave sends a self-update commit with `status: "removed"` via `sendSelfLeaveMessage`. The group admin detects this in `_proccessTryProposalIn` (update commit + `UserStatusType.removed`) and calls `removeMembers` to formally remove the member.

### Key Update (Commit)

Members periodically rotate their own leaf key via `selfUpdateKey`. This:

1. Waits for EOSE.
2. Calls `_selfUpdateKeyLocal` → `rust_mls.selfUpdate` to create a self-update proposal.
3. Sends the commit via `sendEncryptedMessage`.
4. Calls `rust_mls.selfCommit`.
5. Rotates the listening key via `replaceListenPubkey`.

### Group Dissolution

The admin calls `dissolve`, which:

1. Calls `rust_mls.updateGroupContextExtensions` with `status: "dissolved"`.
2. Sends the extension update commit to all members.
3. Deletes the local room record.

Members receive this commit in `_proccessTryProposalIn` → `_handleGroupInfo`, which sets `room.status = RoomStatus.dissolved`.

---

## Message Flow

### Sending a Message

```
User input
  │
  ├── rust_mls.createMessage(nostrId, groupId, msg)
  │     └── Returns: EncryptedMessage { encryptMsg, ... }
  │
  ├── rust_nostr.generateSimple()    ← random sender keypair for anonymity
  │
  └── NostrAPI.sendEventMessage(
        to: room.onetimekey,         ← epoch-derived subscription key
        content: encryptMsg,
        kind: NIP-17 (kind 1059),
        encryptType: mls,
      )
```

### Receiving a Message

```
Nostr relay → WebSocket → kind 445 event
  │
  ├── decryptMessage(room, event, failedCallback)
  │     │
  │     ├── rust_mls.parseMlsMsgType()
  │     │
  │     ├── [commit]      → _proccessTryProposalIn()
  │     │     ├── rust_mls.getSender()
  │     │     ├── rust_mls.othersCommitNormal()   ← advance epoch
  │     │     ├── _proccessUpdateKeys()            ← rotate subscription key
  │     │     └── RoomService.receiveDM()          ← save system message
  │     │
  │     └── [application] → _proccessApplication()
  │           ├── rust_mls.decryptMessage()        ← get plaintext + sender
  │           └── RoomService.receiveDM()           ← save chat message
  │
  └── [unsupported types: proposal, welcome, groupInfo, keyPackage] → Exception
```

### Welcome / Invitation Flow

```
Inviter                               Invitee
  │                                     │
  ├── addMemberToGroup()               │
  │     ├── rust_mls.addMembers()       │
  │     └── _sendInviteMessage()        │
  │           └── NIP-17 kind 444 ────►│
  │                                     ├── handleWelcomeEvent()
  │                                     │     └── save pending invite message
  │                                     │
  │                                     └── User accepts →
  │                                           createGroupFromInvitation()
  │                                             ├── rust_mls.joinMlsGroup(welcome)
  │                                             ├── getGroupExtension()
  │                                             └── replaceListenPubkey()
```

---

## Epoch Management

Each MLS commit advances the **epoch** — a monotonically increasing counter representing the group's cryptographic state. After each epoch transition:

1. The **export secret** changes → a new listening key is derived.
2. The **subscription key** (`room.onetimekey`) is updated via `replaceListenPubkey`.
3. The WebSocket unsubscribes from the old key and subscribes to the new one.

The `room.version` field stores the timestamp of the last known epoch (set to `event.createdAt` on incoming commits), used as the `since` parameter when re-subscribing.

### Key Recovery on Restart

`fixMlsOnetimeKey` is called at app startup to repair any rooms whose `onetimekey` is stale (e.g., from a crashed commit operation). It:

1. Waits for the room's controller to finish processing pending messages.
2. Calls `rust_mls.getListenKeyFromExportSecret` to derive the expected key.
3. Updates the room and re-subscribes if the stored key differs.

---

## Key Data Structures

### Room (relevant MLS fields)

| Field           | Type            | Description                                            |
|-----------------|-----------------|--------------------------------------------------------|
| `toMainPubkey`  | `String`        | The MLS group ID (random secp256k1 pubkey)             |
| `onetimekey`    | `String?`       | Current epoch subscription key (changes per commit)    |
| `version`       | `int`           | Unix timestamp of last known epoch transition          |
| `groupType`     | `GroupType.mls` | Identifies this room as an MLS group                   |
| `sendingRelays` | `List<String>`  | Nostr relays used for this group                       |
| `sentHelloToMLS`| `bool`          | Whether the greeting self-update has been sent         |

### GroupExtension

Stored in the MLS group context extensions (fetched via `rust_mls.getGroupExtension`):

| Field         | Description                                  |
|---------------|----------------------------------------------|
| `name`        | Human-readable group name                    |
| `description` | Group description string                     |
| `admins`      | List of admin pubkeys (hex)                  |
| `relays`      | Preferred Nostr relay URLs                   |
| `status`      | Group status: `"enabled"` or `"dissolved"`   |

### RoomMember (MLS-specific fields)

| Field          | Description                                              |
|----------------|----------------------------------------------------------|
| `idPubkey`     | Member's secp256k1 identity pubkey                       |
| `mlsPKExpired` | `true` if the member's key package has expired           |
| `status`       | `UserStatusType`: `invited`, `enabled`, `removed`, etc.  |
| `msg`          | Optional self-update message from the member             |

---

## API Reference

### Public Methods

| Method | Description |
|--------|-------------|
| `initDB(path)` | Initialize MLS database at startup |
| `initIdentities([identities])` | Bootstrap MLS state for each identity |
| `createGroup(name, identity, toUsers, groupRelays)` | Create a new MLS group |
| `createGroupFromInvitation(event, identity, message, groupId)` | Join a group via Welcome message |
| `addMemberToGroup(groupRoom, toUsers)` | Add members to an existing group |
| `removeMembers(room, list)` | Remove members (admin only) |
| `sendSelfLeaveMessage(room)` | Signal intent to leave the group |
| `dissolve(room)` | Dissolve the group (admin only) |
| `decryptMessage(room, event, failedCallback)` | Process an incoming kind 445 event |
| `handleWelcomeEvent(subEvent, sourceEvent, relay)` | Process an incoming kind 444 invitation |
| `sendMessage(room, message)` | Send an encrypted group message |
| `sendEncryptedMessage(room, message)` | Send a raw MLS payload (system use) |
| `selfUpdateKey(room, msg, [extension])` | Rotate own leaf key with optional metadata |
| `sendGreetingMessage(room)` | Send hello message on first join |
| `sendJoinGroupRequest(gim, identity)` | Request to join a group via admin |
| `shareToFriends(room, toUsers, realMessage)` | Share a group invite with contacts |
| `updateGroupName(room, newName)` | Update group name (admin only) |
| `uploadKeyPackages(identities)` | Publish key packages to relays |
| `getKeyPackagesFromRelay(pubkeys)` | Fetch multiple key packages from relays |
| `getKeyPackageFromRelay(pubkey, [toRelay])` | Fetch a single key package from relay |
| `getMembers(room)` | Get current membership list |
| `getGroupExtension(room)` | Get group metadata from MLS extensions |
| `getShareInfo(room)` | Generate signed group share link |
| `replaceListenPubkey(room)` | Rotate epoch subscription key |
| `waitingForEose(receivingKey, [relays])` | Wait for relay EOSE before mutations |
| `fixMlsOnetimeKey(rooms)` | Repair stale subscription keys on startup |
| `checkPkIsValid(room, pk)` | Check if a key package is still valid |
| `existExpiredMember(room)` | Check for expired member key packages |

### Rust FFI Calls (via `api_mls.dart`)

| FFI Function | Called By | Description |
|---|---|---|
| `initMlsDb` | `initIdentities` | Initialize Rust MLS state for one identity |
| `createMlsGroup` | `createGroup` | Create MLS group in Rust |
| `joinMlsGroup` | `createGroupFromInvitation` | Join group using Welcome blob |
| `addMembers` | `addMemberToGroup`, `createGroup` | Produce add commit + Welcome |
| `removeMembers` | `removeMembers` | Produce remove commit |
| `selfUpdate` | `_selfUpdateKeyLocal` | Produce self-update proposal |
| `selfCommit` | multiple | Finalize pending proposals into a commit |
| `othersCommitNormal` | `_proccessTryProposalIn` | Apply incoming commit, advance epoch |
| `createMessage` | `sendMessage` | Encrypt application message |
| `decryptMessage` | `_proccessApplication` | Decrypt application message |
| `parseMlsMsgType` | `decryptMessage` | Identify message type before routing |
| `getSender` | `_proccessTryProposalIn` | Get sender pubkey from commit |
| `getListenKeyFromExportSecret` | `replaceListenPubkey`, `fixMlsOnetimeKey` | Derive epoch subscription key |
| `getGroupExtension` | `getGroupExtension` | Read group context extensions |
| `updateGroupContextExtensions` | `updateGroupName`, `dissolve` | Commit group metadata changes |
| `getMemberExtension` | `getMembers` | Read per-member leaf extensions |
| `getGroupMembersWithLifetime` | `getMembers`, `existExpiredMember` | Get member key package expiry times |
| `getLeadNodeIndex` | `removeMembers` | Get member's ratchet tree leaf index |
| `createKeyPackage` | `_createKeyPackageEvent` | Generate a new MLS key package |
| `parseLifetimeFromKeyPackage` | `checkPkIsValid` | Read expiry from a key package |

---

## Integration Guide

### App Startup

```dart
// In app initialization:
await MlsGroupService.instance.initDB(dbPath);

// After all groups are loaded:
await MlsGroupService.instance.fixMlsOnetimeKey(mlsRooms);

// Upload key packages so others can invite this user:
await MlsGroupService.instance.uploadKeyPackages(
  identities: identities,
);
```

### Adding a New Identity

```dart
await MlsGroupService.instance.initIdentities([newIdentity]);
await MlsGroupService.instance.uploadKeyPackages(
  identities: [newIdentity],
  forceUpload: true,
);
```

### Creating a Group

```dart
// Fetch invitee key packages first:
final keyPackagesMap = await MlsGroupService.instance
    .getKeyPackagesFromRelay(inviteePubkeys);

final toUsers = inviteePubkeys.map((pk) => {
  'pubkey': pk,
  'name': contactNames[pk],
  'mlsPK': keyPackagesMap[pk],
}).toList();

final room = await MlsGroupService.instance.createGroup(
  'My Group',
  identity,
  toUsers: toUsers,
  groupRelays: ['wss://relay.example.com'],
);
```

### Receiving Group Messages

Group messages arrive on the room's `onetimekey` subscription. The WebSocket service routes them to:

```dart
// For kind 445 events on an MLS group room:
await MlsGroupService.instance.decryptMessage(
  room,
  event,
  (error) => logger.e('MLS decrypt failed: $error'),
);

// For kind 444 welcome events:
await MlsGroupService.instance.handleWelcomeEvent(
  subEvent: subEvent,
  sourceEvent: sourceEvent,
  relay: relay,
);
```

---

## Known Limitations / Deprecated Features

### Deprecated

| Symbol | Location | Reason | Action |
|--------|----------|--------|--------|
| `processMessage()` | `mls_group.service.dart:557` | Superseded by `decryptMessage` dispatch logic | Remove; callers should use `decryptMessage` |
| Commented-out `getMembers()` call | `existExpiredMember` | Replaced by direct lifetime query | Remove commented line |

### Known Limitations

- **Key package expiry** — MLS key packages expire after 90 days of relay storage (30-day upload refresh). If a user is offline for >90 days, they cannot be added to a group until they come back online and re-upload their key package.

- **Admin-only removal** — Voluntary leave (`sendSelfLeaveMessage`) requires the admin to be online to process the removal request. If the admin is offline, the leaving member remains in the ratchet tree.

- **Single admin** — The current implementation supports a single admin per group (set at creation). Admin transfer is not implemented.

- **TODO: key package consumption tracking** — `uploadKeyPackages` does not yet verify whether an existing key package has already been used in an `addMembers` operation. This could result in the same key package being reused, which the MLS spec prohibits. See the TODO comment in `uploadKeyPackages`.

- **Method name typo** — `addMemberToGroup` has a typo (`Memeber` should be `Member`). Renaming is deferred to avoid breaking all call sites simultaneously.
