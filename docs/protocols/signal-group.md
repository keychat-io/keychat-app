# Signal Protocol — Group Chat

## Overview

Keychat implements Signal-based group messaging using a **pairwise encryption** model
called `sendAll`. Rather than a shared group key, each message is individually
encrypted with Signal's Double Ratchet algorithm and sent to every group member
over their own 1:1 Signal session.

This model trades bandwidth for security: each member has perfect forward secrecy
and post-compromise security independently of every other member. A compromised
member's session does not expose messages sent to other members.

**Supported group types:**

| `GroupType`  | Description                                       | Status       |
|--------------|---------------------------------------------------|--------------|
| `sendAll`    | Pairwise Signal encryption to all members         | Active       |
| `mls`        | MLS group encryption (see `mls-group.md`)         | Active       |
| `kdf`        | KDF-based shared key (legacy)                     | Deprecated   |
| `shareKey`   | Shared Nostr keypair (legacy)                     | Deprecated   |

---

## Group Creation Flow

```
Creator                                     Nostr Relay
   |                                              |
   |-- rust_nostr.generateSimple() ------------> random keypair (group identity)
   |-- SignalIdService.createSignalId() -------> Signal identity for group
   |-- _createGroupToDB() --------------------- persist Room (GroupType.sendAll)
   |-- room.addMember(creator, isAdmin=true) --> add self as admin member
   |
   | [Group is now local only; no relay traffic until first invite]
```

**Key objects created:**

- `Room` with `type = RoomType.group`, `groupType = GroupType.sendAll`
- `SignalId` linked via `room.signalIdPubkey` — used to identify the group's Signal sender
- Creator added as `RoomMember` with `status = UserStatusType.invited`, `isAdmin = true`

---

## Member Management

### Inviting Members (`inviteToJoinGroup`)

```
Admin                    Invitee A               Invitee B
  |                          |                       |
  |-- build RoomProfile ---> |                       |
  |   (members, name,        |                       |
  |    groupType, version)   |                       |
  |                          |                       |
  |-- Nip4ChatService -----> NIP-04 encrypted invite |
  |                          |                       |
  |-- Nip4ChatService --------------------------------> NIP-04 encrypted invite
  |                          |                       |
  [Admin saves invite msg in group room]
```

- Each invitee receives a `KeychatMessage` with `type = KeyChatEventKinds.groupInvite`
- The `RoomProfile` payload contains: group pubkey, name, all current members,
  group type, version timestamp, and optionally the group's shared private key
- Recipient processes the invite via `processInvite()` → creates local group room

### Member Status Lifecycle

```
inviting → invited → (active participant)
                  ↘ removed
```

| Status       | Meaning                                      |
|--------------|----------------------------------------------|
| `inviting`   | Invite sent, awaiting acceptance             |
| `invited`    | Member active in group (sent groupHi)        |
| `removed`    | Removed by admin or self-exited              |

### Removing a Member (`removeMember` / `_removeMemberPairwise`)

1. Admin calls `removeMember(room, rm)`
2. Sends a `KeyChatEventKinds.groupRemoveSingleMember` broadcast to all members
3. Locally sets the member's status to disabled via `room.setMemberDisable(rm)`
4. The removed member receives a pairwise DM notification (via `_processGroupRemoveSingleMember`)
5. Recipient marks room as `RoomStatus.removedFromGroup`

### Self-Exit (`selfExitGroup`)

1. Non-admin member calls `selfExitGroup(room)`
2. Sends `KeyChatEventKinds.groupSelfLeave` broadcast
3. Deletes the group room locally
4. Other members receive the self-leave event and remove the member from their local list

### Group Dissolution (`dissolveGroup`)

1. Admin calls `dissolveGroup(room)`
2. Broadcasts `KeyChatEventKinds.groupDissolve` to all active members
3. Deletes the group room locally
4. Recipients mark room as `RoomStatus.dissolved`

---

## Key Distribution

Unlike classic Signal group sessions (Sender Keys / `SenderKeyDistributionMessage`),
the `sendAll` group type does **not** use a shared group sender key. Instead:

- Each outbound group message is encrypted individually per member
- Encryption uses the existing pairwise Signal session between the sender and each recipient
- Sessions are established on first contact via the standard Signal X3DH handshake

**Message flow for `sendToAllMessage`:**

```
Sender
  |
  |-- build GroupMessage { pubkey, message, subtype, ext }
  |-- wrap in KeychatMessage { type: groupSendToAllMessage }
  |
  |-- for each memberRoom (parallel, max 10):
  |     |-- SignalChatService.sendMessage(idRoom, payload)  [pairwise Signal]
  |     |-- collect NostrEventModel
  |
  |-- publish all events to Nostr relay
  |-- save single outbound Message record
```

**Message reception flow:**

```
Recipient
  |
  |-- receives NIP-04/NIP-17 event from sender's identity pubkey
  |-- SignalChatService decrypts → KeychatMessage
  |-- GroupService.proccessMessage()
  |     |-- type == groupSendToAllMessage
  |     |-- decode inner GroupMessage (group pubkey, actual content)
  |     |-- look up groupRoom by GroupMessage.pubkey
  |     |-- processGroupMessage(groupRoom, event, gm)
  |           |-- save Message to DB
  |           |-- handle system subtypes (join/leave/rename/dissolve)
```

---

## API Reference

### GroupService

| Method | Description |
|--------|-------------|
| `createGroup(name, identity, type)` | Creates a new group room locally |
| `inviteToJoinGroup(room, toUsers)` | Invites users and sends RoomProfile invitations |
| `processInvite(idRoom, event, roomProfile, msg)` | Handles an incoming group invitation |
| `sendToAllMessage(room, message)` | Sends an encrypted message to all members |
| `sendMessageToGroup(room, message)` | Routes message to MLS or sendAll handler |
| `processGroupMessage(room, event, gm)` | Processes and persists an incoming group message |
| `proccessMessage(room, km, event)` | Top-level dispatch for group-typed messages |
| `removeMember(room, rm)` | Removes a member from the group |
| `selfExitGroup(room)` | Current user exits the group |
| `dissolveGroup(room)` | Admin permanently closes the group |
| `changeMyNickname(room, name)` | Broadcasts a nickname change |
| `changeRoomName(roomId, name)` | Admin renames the group |
| `sendInviteToAdmin(room, accounts)` | Non-admin requests admin to invite accounts |
| `getRoomProfile(room)` | Builds a RoomProfile snapshot for invitations |
| `updateRoomMykey(room, mykey)` | Updates the shared key for shareKey groups |

### GroupTx

| Method | Description |
|--------|-------------|
| `joinGroup(roomProfile, identity)` | Creates a group room from a received invitation |
| `importMykeyTx(identityId, keychain)` | Imports or retrieves a Mykey record |
| `updateRoom(room, updateMykey)` | Persists room and optionally its mykey link |

---

## Integration Guide

### Sending a Group Message

```dart
// Preferred: route through sendMessageToGroup (handles both MLS and sendAll)
await GroupService.instance.sendMessageToGroup(
  room,
  'Hello everyone!',
);

// Direct sendAll (skips MLS routing)
await GroupService.instance.sendToAllMessage(room, 'Hello!');
```

### Creating a Group and Inviting Members

```dart
// 1. Create the group
final room = await GroupService.instance.createGroup(
  'My Group',
  identity,
  GroupType.sendAll,
);

// 2. Invite members (Map<idPubkey, displayName>)
await GroupService.instance.inviteToJoinGroup(
  room,
  {'abc123...': 'Alice', 'def456...': 'Bob'},
);
```

### Handling Incoming Group Events

Incoming events are dispatched by `ChatService` → `GroupService.proccessMessage()`.
No manual routing is needed at the UI layer.

### Joining a Group (from Invitation)

Called automatically by `processInvite()` when the group room does not yet exist:

```dart
// Inside a writeTxn block:
final groupRoom = await GroupTx.instance.joinGroup(roomProfile, identity);
```

---

## Known Limitations / Deprecated Features

### Deprecated Group Types

- **`GroupType.kdf`**: KDF-based shared key group. No longer actively developed.
  `removeMember()` throws for this type. Candidate for removal once all users
  have migrated.
- **`GroupType.shareKey`**: Shared Nostr keypair group. Same status as `kdf`.
  Both are guarded with `throw Exception('not support')` in current code.

### Unsupported Override

- `GroupService.sendMessage()` always throws `Exception('unsupported method')`.
  This is an intentional override to satisfy the `BaseChatService` contract.
  Callers must use `sendMessageToGroup()` or `sendToAllMessage()` instead.

### Commented-Out Parallel Queue in `_invitePairwiseGroup`

The original implementation of `_invitePairwiseGroup` used a `Queue(parallel: 5)`
for concurrent invite delivery. This was replaced with a sequential loop to avoid
race conditions during member room creation. The commented-out queue code is dead
and is a candidate for removal.

### No Forward Secrecy on Group Roster Changes

When a member is removed, existing Signal sessions between the removed member and
remaining members are not re-keyed. The removed member retains decryption ability
for messages sent before removal. A full re-key on membership change would require
distributing new Signal sessions to all remaining members — this is not currently
implemented for `sendAll` groups (MLS handles this via epoch commits).
