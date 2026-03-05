# Merge Strategy

**Date:** 2026-03-05

## Branch Overview

| Branch            | Focus Area                        | Files Likely Touched                                      |
|-------------------|-----------------------------------|-----------------------------------------------------------|
| `team/nostr`      | Nostr core, relay, NIP handling   | `nostr-core/`, `service/relay.service.dart`, `nostr.dart` |
| `team/other`      | Misc utilities, ecash, config     | `keychat_ecash/`, shared utilities                        |
| `team/signal-chat`| Signal 1:1 chat service           | `service/signal_chat*.dart`, `service/signalId.service.dart` |
| `team/signal-group`| Signal group service             | `service/group.service.dart`, `service/group_tx.dart`     |
| `team/mls-group`  | MLS group service                 | `service/mls_group.service.dart`                          |
| `team/cto`        | Protocol docs, plans              | `docs/protocols/`, `docs/plans/`                          |

---

## Recommended Merge Order

1. **`team/nostr`** — Merge first. Nostr core (event handling, relay management, NIP
   utilities) is a shared dependency used by all other modules. Stabilizing this layer
   first reduces conflict surface for subsequent merges.

2. **`team/other`** — Merge second. Ecash and shared utilities are consumed by chat
   services but do not depend on signal or MLS modules.

3. **`team/signal-chat`** — Merge third. The 1:1 Signal chat service depends on Nostr
   for transport but is otherwise independent of group services.

4. **`team/signal-group`** — Merge fourth. Signal group service calls into
   `SignalChatService` for pairwise encryption; requires `team/signal-chat` to be
   merged first.

5. **`team/mls-group`** — Merge fifth. MLS group service uses Nostr transport and Rust
   FFI, but is independent of Signal services. Merging after signal layers reduces the
   chance of conflicts in shared files like `chat.service.dart`.

6. **`team/cto`** — Merge last. Contains only documentation; no production code
   conflicts expected.

---

## Potential Conflicts

### High-Risk Files (touched by multiple branches)

| File | Branches That Touch It | Conflict Risk |
|------|------------------------|---------------|
| `packages/app/lib/service/chat.service.dart` | signal-chat, signal-group, mls-group, nostr | High — central dispatch for all message types |
| `packages/app/lib/nostr-core/nostr.dart` | nostr, signal-chat | Medium — event dispatch and NIP-04 send path |
| `packages/app/lib/models/room.dart` | signal-chat, signal-group, mls-group | Medium — shared data model fields |
| `packages/app/lib/service/room.service.dart` | signal-chat, signal-group, mls-group | Medium — receiveDM and updateRoom used by all |
| `packages/app/lib/service/websocket.service.dart` | nostr, signal-chat, mls-group | Medium — listenPubkey and subscription management |
| `packages/app/lib/constants.dart` | multiple | Low — enum additions may conflict |

### Lower-Risk Files

| File | Branches | Note |
|------|----------|------|
| `service/signal_chat.service.dart` | signal-chat only | Isolated; low conflict risk |
| `service/mls_group.service.dart` | mls-group only | Isolated; low conflict risk |
| `service/group.service.dart` | signal-group only | Isolated; low conflict risk |
| `service/relay.service.dart` | nostr only | Isolated; low conflict risk |
| `docs/` | cto only | Documentation only; no code conflicts |

---

## Pre-Merge Checklist

### For each branch before merging:

- [ ] Run `melos run lint:all` on the branch and resolve all analyzer warnings
- [ ] Run `melos run test:all` — all tests must pass
- [ ] Confirm no `// DEPRECATED` marked code has been deleted without product owner sign-off
- [ ] Confirm any new Isar model fields have a corresponding `melos run build:runner` pass
- [ ] Review `chat.service.dart` diff carefully for routing changes

### Before merging `team/signal-group`:

- [ ] Confirm `team/signal-chat` is already merged into main
- [ ] Verify `GroupType.kdf` and `GroupType.shareKey` enum values are still present
  (removal requires product owner decision — see `deprecated-code-review.md`)

### Before merging `team/mls-group`:

- [ ] Confirm `team/nostr` and `team/other` are merged
- [ ] Verify `MlsGroupService.proccessMessage()` caller audit is complete if the function
  was removed (see `deprecated-code-review.md`)
- [ ] If `rust/src/api_mls.rs` was modified, regenerate Dart bindings:
  `flutter_rust_bridge_codegen generate`

### Before merging `team/cto`:

- [ ] Deprecated code decisions confirmed by product owner
- [ ] All 3 protocol docs reviewed and signed off

---

## Post-Merge Verification

```bash
# After all branches merged into main:
melos bootstrap
melos run lint:all
melos run test:all
melos run build:runner    # if any Isar models changed

# Run the app on a device and verify:
# - 1:1 Signal chat: send and receive messages
# - Signal group: create group, invite member, send message
# - MLS group: create group, add member, send message, key rotation
```

---

## Notes on Deprecated Code Decisions

Before the final merge, the product owner should make explicit decisions on:

1. **`GroupType.kdf` / `GroupType.shareKey`** — keep enum values or add migration?
   (Required before `team/signal-group` merge)

2. **`MlsGroupService.proccessMessage()`** — delete after caller audit or keep with
   deprecation annotation?

3. **NIP-02 functions** — safe to delete `_proccessNip2` and `sendNip2Message`?
   (Low risk, but verify dispatch table in `nostr.dart` does not route to them)

See `docs/plans/deprecated-code-review.md` for full analysis.
