# Team Worktrees Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Set up 6 parallel git worktrees with dedicated agents to perform code cleanup, add missing documentation, mark deprecated code, and produce protocol documentation for Keychat's core modules.

**Architecture:** Phase 1 runs 5 module agents in parallel (signal-chat, signal-group, mls-group, nostr, other), each working in an isolated git worktree. Phase 2 runs a CTO agent that reviews all outputs, standardizes protocol docs, and produces a deprecated code decision list.

**Tech Stack:** Flutter/Dart, GetX, Isar, Rust FFI (flutter_rust_bridge), Nostr Protocol, Signal Protocol, MLS Protocol

---

## Rules for All Agents

- All output (comments, docs, commit messages) must be in **English**
- Use `///` for public API doc comments, `//` for inline implementation notes
- Mark deprecated code with `// DEPRECATED: <reason> - candidate for removal` — do NOT delete
- Do NOT touch files outside your assigned ownership list
- Do NOT refactor beyond what is necessary for clarity

---

## Task 1: Create All Worktrees

**Performed by:** Orchestrator (main session)

**Step 1: Create module worktrees from current HEAD**

```bash
cd /Users/liuxing/Documents/gitproject/keychat-melos

git worktree add .claude/worktrees/signal-chat-agent -b team/signal-chat
git worktree add .claude/worktrees/signal-group-agent -b team/signal-group
git worktree add .claude/worktrees/mls-group-agent -b team/mls-group
git worktree add .claude/worktrees/nostr-agent -b team/nostr
git worktree add .claude/worktrees/other-agent -b team/other
git worktree add .claude/worktrees/cto-agent -b team/cto
```

**Step 2: Verify worktrees exist**

```bash
git worktree list
```

Expected: 7 entries (main + 6 new worktrees)

---

## Task 2: signal-chat Agent

**Worktree:** `.claude/worktrees/signal-chat-agent`
**Branch:** `team/signal-chat`

**Owned files:**
- `packages/app/lib/service/signal_chat.service.dart` (678 lines)
- `packages/app/lib/service/signal_chat_util.dart` (91 lines)
- `packages/app/lib/service/signalId.service.dart` (216 lines)

**Step 1: Read all owned files**

Read each file fully. Understand the Signal Protocol flow:
- Key exchange (X3DH / Double Ratchet)
- Session initialization and management
- Message encryption/decryption
- Identity key management

**Step 2: Add missing doc comments**

For every public method missing a `///` comment, add one. Example pattern:

```dart
/// Encrypts and sends a message to the specified room using Signal Protocol.
///
/// Creates a new session if one does not exist for the recipient.
/// Returns the encrypted ciphertext as a base64 string.
///
/// Throws [SignalSessionException] if session initialization fails.
Future<String> sendMessage(Room room, String plaintext) async {
```

**Step 3: Mark deprecated code**

Identify functions/fields that appear unused, have been superseded, or contain TODO/FIXME comments indicating removal. Add:

```dart
// DEPRECATED: superseded by signalChatV2 - candidate for removal
```

**Step 4: Write protocol documentation**

Create `docs/protocols/signal-chat.md` using the format below:

```markdown
# Signal Protocol — Private Chat

## Overview
...

## Message Flow
...

## Key Data Structures
...

## API Reference
...

## Integration Guide
...

## Known Limitations / Deprecated Features
...
```

**Step 5: Commit**

```bash
git add packages/app/lib/service/signal_chat.service.dart \
        packages/app/lib/service/signal_chat_util.dart \
        packages/app/lib/service/signalId.service.dart \
        docs/protocols/signal-chat.md
git commit -m "cleanup(signal-chat): add doc comments, mark deprecated code, add protocol doc"
```

---

## Task 3: signal-group Agent

**Worktree:** `.claude/worktrees/signal-group-agent`
**Branch:** `team/signal-group`

**Owned files:**
- `packages/app/lib/service/group.service.dart` (1081 lines)
- `packages/app/lib/service/group_tx.dart` (126 lines)

**Step 1: Read all owned files**

Understand the Signal-based group chat implementation:
- Group key distribution mechanism
- Member add/remove operations
- Sender keys (SenderKeyDistributionMessage)
- Group message encryption/decryption

**Step 2: Add missing doc comments**

Follow the same pattern as Task 2. Pay special attention to:
- Group creation and invitation flow
- Key rotation on member change
- Transaction handling in `group_tx.dart`

**Step 3: Mark deprecated code**

Look for:
- Functions only called from commented-out code
- Methods with `// TODO: remove` or `// old` comments
- Duplicate logic superseded by newer implementations

**Step 4: Write protocol documentation**

Create `docs/protocols/signal-group.md`:

```markdown
# Signal Protocol — Group Chat

## Overview
...

## Group Creation Flow
...

## Member Management
...

## Key Distribution
...

## API Reference
...

## Integration Guide
...

## Known Limitations / Deprecated Features
...
```

**Step 5: Commit**

```bash
git add packages/app/lib/service/group.service.dart \
        packages/app/lib/service/group_tx.dart \
        docs/protocols/signal-group.md
git commit -m "cleanup(signal-group): add doc comments, mark deprecated code, add protocol doc"
```

---

## Task 4: mls-group Agent

**Worktree:** `.claude/worktrees/mls-group-agent`
**Branch:** `team/mls-group`

**Owned files:**
- `packages/app/lib/service/mls_group.service.dart` (1470 lines)

**Step 1: Read the file**

Understand the MLS (Message Layer Security) group chat:
- Group state machine and epochs
- Welcome message flow
- Commit/Proposal operations
- Member add/remove/update
- Interface with Rust FFI (`api_mls.dart`)

**Step 2: Add missing doc comments**

This is the largest single file. Prioritize:
- All public methods
- Complex state transition logic
- Rust FFI call sites (document what the FFI call does and what it returns)

**Step 3: Mark deprecated code**

MLS is newer; look for:
- Early prototype functions replaced by proper MLS operations
- Workarounds that should be removed once MLS stabilizes
- Any `// TODO: MLS v2` style comments

**Step 4: Write protocol documentation**

Create `docs/protocols/mls-group.md`:

```markdown
# MLS Protocol — Group Chat

## Overview
...

## Group Lifecycle
### Creation
### Member Addition
### Member Removal
### Key Update (Commit)

## Message Flow
...

## Epoch Management
...

## API Reference
...

## Integration Guide
...

## Known Limitations / Deprecated Features
...
```

**Step 5: Commit**

```bash
git add packages/app/lib/service/mls_group.service.dart \
        docs/protocols/mls-group.md
git commit -m "cleanup(mls-group): add doc comments, mark deprecated code, add protocol doc"
```

---

## Task 5: nostr Agent

**Worktree:** `.claude/worktrees/nostr-agent`
**Branch:** `team/nostr`

**Owned files:**
- `packages/app/lib/nostr-core/nostr.dart` (949 lines)
- `packages/app/lib/nostr-core/nostr_event.dart` (253 lines)
- `packages/app/lib/nostr-core/filter.dart` (117 lines)
- `packages/app/lib/nostr-core/relay_websocket.dart` (176 lines)
- `packages/app/lib/nostr-core/request.dart` (35 lines)
- `packages/app/lib/nostr-core/subscribe_result.dart` (64 lines)
- `packages/app/lib/nostr-core/close.dart` (23 lines)
- `packages/app/lib/nostr-core/nostr_nip4_req.dart` (34 lines)
- `packages/app/lib/nostr-core/utils.dart` (21 lines)
- `packages/app/lib/service/nip4_chat.service.dart` (128 lines)
- `packages/app/lib/service/websocket.service.dart` (935 lines)
- `packages/app/lib/service/relay.service.dart` (463 lines)

**Step 1: Read all owned files**

Understand:
- Core Nostr event structure (NIP-01)
- NIP-04 encrypted DM implementation
- NIP-17 private direct message implementation
- WebSocket relay connection management
- Subscription lifecycle

**Step 2: Add missing doc comments**

Focus on:
- Event kind constants (document what each kind means)
- Filter construction methods
- WebSocket connection state machine
- NIP-04 vs NIP-17 differences

**Step 3: Mark deprecated code**

Look for:
- NIP-04 code that may be superseded by NIP-17
- Old relay connection code replaced by newer WebSocket logic
- Unused filter types or event kinds

**Step 4: Commit**

```bash
git add packages/app/lib/nostr-core/ \
        packages/app/lib/service/nip4_chat.service.dart \
        packages/app/lib/service/websocket.service.dart \
        packages/app/lib/service/relay.service.dart
git commit -m "cleanup(nostr): add doc comments and mark deprecated code"
```

---

## Task 6: other Agent

**Worktree:** `.claude/worktrees/other-agent`
**Branch:** `team/other`

**Owned files:**
- `packages/app/lib/service/identity.service.dart` (574 lines)
- `packages/app/lib/service/contact.service.dart` (490 lines)
- `packages/app/lib/service/room.service.dart` (1068 lines)
- `packages/app/lib/service/message.service.dart` (699 lines)
- `packages/app/lib/service/chat.service.dart` (24 lines)
- `packages/app/lib/service/chatx.service.dart` (402 lines)
- `packages/app/lib/service/wallet_connection_crypto.dart` (78 lines)
- `packages/app/lib/service/wallet_connection_storage.dart` (155 lines)
- `packages/app/lib/service/message_retry.service.dart` (284 lines)
- `packages/app/lib/service/local_notification_service.dart` (253 lines)
- `packages/app/lib/service/notify.service.dart` (499 lines)
- `packages/app/lib/service/qrscan.service.dart` (268 lines)
- `packages/app/lib/service/s3.dart` (80 lines)
- `packages/keychat_ecash/lib/` (ecash package, ~2929 lines total)

**Step 1: Read all owned files**

This is the "everything else" module. Understand:
- Identity and key management
- Contact/room/message data layer
- Ecash/Cashu operations
- Wallet connection (NWC)
- Notification routing
- Message retry logic

**Step 2: Add missing doc comments**

Prioritize larger files first: `room.service.dart`, `message.service.dart`, `notify.service.dart`, `identity.service.dart`.

**Step 3: Mark deprecated code**

Special attention to:
- `chat.service.dart` — only 24 lines, likely a thin wrapper; check if it's still used
- Any retry logic that has been replaced
- Old ecash integration points

**Step 4: Commit**

```bash
git add packages/app/lib/service/identity.service.dart \
        packages/app/lib/service/contact.service.dart \
        packages/app/lib/service/room.service.dart \
        packages/app/lib/service/message.service.dart \
        packages/app/lib/service/chat.service.dart \
        packages/app/lib/service/chatx.service.dart \
        packages/app/lib/service/wallet_connection_crypto.dart \
        packages/app/lib/service/wallet_connection_storage.dart \
        packages/app/lib/service/message_retry.service.dart \
        packages/app/lib/service/local_notification_service.dart \
        packages/app/lib/service/notify.service.dart \
        packages/app/lib/service/qrscan.service.dart \
        packages/app/lib/service/s3.dart \
        packages/keychat_ecash/lib/
git commit -m "cleanup(other): add doc comments and mark deprecated code"
```

---

## Task 7: CTO Agent

**Worktree:** `.claude/worktrees/cto-agent`
**Branch:** `team/cto`

**Runs after:** Tasks 2–6 are complete

**Step 1: Read all 5 module branches**

Fetch and read the produced outputs:

```bash
git fetch origin team/signal-chat team/signal-group team/mls-group team/nostr team/other
```

Read each module's committed changes and protocol docs.

**Step 2: Review and standardize protocol docs**

Read all three protocol docs:
- `docs/protocols/signal-chat.md`
- `docs/protocols/signal-group.md`
- `docs/protocols/mls-group.md`

Ensure consistent:
- Heading structure
- Section naming
- API reference format
- Integration guide completeness

Edit to standardize. Do not change technical content, only format and structure.

**Step 3: Compile deprecated code list**

Create `docs/plans/deprecated-code-review.md`:

```markdown
# Deprecated Code Review

**Date:** YYYY-MM-DD
**Reviewer:** CTO Agent

## Summary

| File | Symbol | Reason | Recommendation |
|------|--------|--------|----------------|
| signal_chat.service.dart | `oldMethod()` | Superseded by v2 | Delete |
| ... | ... | ... | ... |

## Decisions Required

Items that need product owner decision before action:
...

## Safe to Delete

Items with no callers and clear replacement:
...
```

**Step 4: Write merge strategy**

Create `docs/plans/merge-strategy.md` describing the order and approach for merging all 5 module branches into main.

**Step 5: Commit**

```bash
git add docs/protocols/ docs/plans/deprecated-code-review.md docs/plans/merge-strategy.md
git commit -m "review(cto): standardize protocol docs, compile deprecated code list, write merge strategy"
```

---

## Execution Order

```
Task 1 (create worktrees)
        |
        +-- Task 2 (signal-chat) --|
        +-- Task 3 (signal-group) -|
        +-- Task 4 (mls-group)   --|-- Task 7 (CTO review)
        +-- Task 5 (nostr)       --|
        +-- Task 6 (other)       --|
```

Tasks 2–6 run in **parallel**. Task 7 runs only after all of Tasks 2–6 complete.
