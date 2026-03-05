# Deprecated Code Review

**Date:** 2026-03-05
**Reviewer:** CTO Agent

## Summary Table

| Module        | File                          | Symbol / Line                          | Reason Marked Deprecated                                                                 | Recommendation                                                                 |
|---------------|-------------------------------|----------------------------------------|------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| signal-group  | `service/group.service.dart`  | Line 666 — `GroupType.shareKey / kdf`  | Both types throw `Exception('not support')` in `removeMember`; no active callers         | Safe to delete once all users have migrated off legacy groups                  |
| signal-group  | `service/group.service.dart`  | Line 684 — `sendMessage()` override    | Intentional unsupported override; callers must use `sendMessageToGroup()` instead        | Keep as intentional guard; add `@Deprecated` annotation + clear throw message  |
| mls-group     | `service/mls_group.service.dart` | Line 634 — `proccessMessage()`       | Superseded by `decryptMessage` dispatch logic                                            | Safe to delete; verify no external callers remain                              |
| mls-group     | `service/mls_group.service.dart` | Line 1660 — commented `getMembers()` | Replaced by direct `getGroupMembersWithLifetime` call in `existExpiredMember`            | Safe to delete the commented-out line                                          |
| nostr         | `nostr-core/utils.dart`       | Line 14 — `unEscapeChars()`            | Identical logic to `addEscapeChars`; does not actually unescape; misleading name         | Safe to delete; verify no callers reference this function                      |
| nostr         | `nostr-core/nostr.dart`       | Line 209 — `_proccessNip2()`           | NIP-02 contact list processing body is entirely commented out                            | Safe to delete; NIP-02 is not planned for reactivation                         |
| nostr         | `nostr-core/nostr.dart`       | Line 257 — `sendNip2Message()`         | Body is entirely commented out; NIP-02 contact list sync disabled                        | Safe to delete alongside `_proccessNip2`                                       |
| nostr         | `service/relay.service.dart`  | Line 93 — `getReadList()` / `getWriteList()` | Read/write relay split removed; replaced by single `active` flag                 | Safe to delete (already commented out); remove comment block                  |

**Total DEPRECATED markers by module:**

| Module       | Count |
|--------------|-------|
| signal-chat  | 0     |
| signal-group | 2     |
| mls-group    | 2     |
| nostr        | 4     |
| other        | 0     |
| **Total**    | **8** |

---

## Safe to Delete

These items have no active callers and a clear replacement exists. Removal is low-risk.

### 1. `unEscapeChars()` — `nostr-core/utils.dart:14`

- **Problem:** Function is misnamed (it does not unescape) and is logically identical to
  `addEscapeChars`. Any caller relying on this function is getting escape behavior, not
  unescape behavior — a latent bug.
- **Action:** Delete the function. Callers (if any) should use `addEscapeChars` instead.

### 2. `_proccessNip2()` and `sendNip2Message()` — `nostr-core/nostr.dart:209, 257`

- **Problem:** Both functions have fully commented-out bodies. NIP-02 contact list
  sync is disabled and not on the roadmap.
- **Action:** Delete both functions and remove any dispatch site that calls `_proccessNip2`.

### 3. Read/Write relay split comment block — `service/relay.service.dart:93`

- **Problem:** Commented-out `getReadList()` / `getWriteList()` stubs from an older
  architecture where relays were split into read vs. write pools.
- **Action:** Remove the comment block entirely.

### 4. Commented-out `getMembers()` line — `mls_group.service.dart:1660`

- **Problem:** A single commented-out call that has been superseded by a direct
  `getGroupMembersWithLifetime` invocation in the same method.
- **Action:** Remove the dead comment line.

### 5. Commented-out parallel queue — `group.service.dart` (`_invitePairwiseGroup`)

- **Problem:** The original `Queue(parallel: 5)` implementation was replaced by a
  sequential loop. The dead queue code remains as a comment. (Noted in the signal-group
  protocol doc, not marked with `// DEPRECATED` tag but is dead code.)
- **Action:** Remove the commented-out queue block.

---

## Requires Product Owner Decision

These items require a product decision before deletion because they may still serve
users on old data, or because removal changes observable behavior.

### 1. `GroupType.kdf` and `GroupType.shareKey` — `group.service.dart:666`

- **Context:** Both legacy group types are blocked at the service layer with
  `throw Exception('not support')` in `removeMember`. However, existing `Room` records
  in user databases may still have `groupType = kdf` or `groupType = shareKey`. Deleting
  the enum values would break deserialization of those records.
- **Risk:** High — could cause crashes for users with old group rooms on upgrade.
- **Options:**
  1. Leave enum values but keep the `throw` guard (current state, lowest risk).
  2. Add a migration that converts old group rooms to a tombstone/dissolved state before
     removing the enum values.
  3. Add a UI banner warning users their group is unsupported and prompt dissolution.
- **Decision needed:** Can we confirm all users have migrated? If not, pick option 2 or 3.

### 2. `GroupService.sendMessage()` unsupported override — `group.service.dart:684`

- **Context:** This override satisfies the `BaseChatService` contract but throws
  `Exception('unsupported method')` unconditionally. It is intentional, not accidental.
  Callers that accidentally call this instead of `sendMessageToGroup()` will get a
  runtime exception with no compile-time warning.
- **Risk:** Low for deletion of the override itself; medium if the base contract is removed.
- **Recommendation:** Add a `@Deprecated` Dart annotation with a message pointing to
  `sendMessageToGroup()`. Do not delete — the base-class contract requires it.

### 3. `MlsGroupService.proccessMessage()` — `mls_group.service.dart:634`

- **Context:** Marked as superseded by `decryptMessage`. However, it is a public method
  (lowercase `p` in `proccessMessage` matches the `BaseChatService` interface contract).
  Removing it requires verifying all callers in `ChatService` and `GroupService` have
  been updated to call `decryptMessage` instead.
- **Risk:** Medium — interface contract breakage if removed without updating all callers.
- **Action:** Audit callers. If confirmed zero external call sites, remove.

---

## Cross-Module Observations

### Typo Propagation: `proccessMessage` vs `processMessage`

Both `GroupService` and `MlsGroupService` use the method name `proccessMessage`
(double-c). This is a typo inherited from `BaseChatService`. Renaming requires a
coordinated change across all implementations and call sites. This is **not** marked
as deprecated in the codebase but is a known technical debt item noted in the MLS
protocol doc. Recommend fixing during a dedicated refactor sprint, not inline.

### Method Typo: `addMemeberToGroup` in `MlsGroupService`

`addMemeberToGroup` (`Memeber` should be `Member`) is a public API typo noted in the
MLS protocol doc. Renaming would break all call sites. Track as a deferred rename.

### NIP-02 Removal is Self-Contained

The NIP-02 functions (`_proccessNip2`, `sendNip2Message`) in `nostr-core/nostr.dart`
appear to be self-contained. The `syncContact` function that sends the REQ is still
active (it fetches contact lists) but does not call `_proccessNip2` — the response
handler dispatch path for `EventKinds.contactList` should be verified before deleting
to ensure it does not route to the deprecated function.

### No DEPRECATED Markers in `signal-chat`, `other` Modules

The signal-chat and other-agent modules contain no `// DEPRECATED` markers. The
signal-chat codebase is clean; any legacy patterns (e.g., `processListenAddrs` window
management) are active code, not deprecated.
