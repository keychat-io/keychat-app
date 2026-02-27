# Keychat — AI Coding Agent Instructions

## 🌍 Language Policy (CRITICAL)

**All code-related content MUST be written in English:**

- ✅ Code comments (both `///` and `//`)
- ✅ Function/class/variable names
- ✅ Documentation strings (docstrings)
- ✅ Git commit messages
- ✅ Error messages in code
- ✅ Test descriptions
- ✅ TODO/FIXME notes

**Only user-facing content uses localized languages:**

- UI text (via i18n/localization)
- User error messages (displayed through `EasyLoading`)
- Documentation for end users

**Why:** This is an international open-source project. English ensures all developers worldwide can contribute and maintain the codebase.

## Project Overview

Keychat is a privacy-focused secure chat super-app for Bitcoiners. It's a **Flutter + Rust monorepo** managed by **Melos 7.3.0**, using **FVM** (Flutter 3.38.2, Dart ≥3.9.0).

Three packages: `packages/app` (main Flutter app), `packages/keychat_ecash` (Bitcoin ecash wallet UI/logic), `packages/keychat_rust_ffi_plugin` (Rust FFI for crypto — Signal, MLS, Nostr, Cashu).

**Design Philosophy:** "Postal system" metaphor — users send messages "stamped" with Bitcoin ecash to Nostr relays (post offices), which collect ecash and deliver encrypted messages. No registration required.

## Architecture

**State management:** GetX exclusively — `Get.put`/`Get.lazyPut` for DI, `.obs` reactive variables, `Obx()` in UI, `Get.find<T>()` for lookup.

**Database:** Isar Community 3.3.0 (NoSQL) for app data; SQLite (via Rust) for Signal/MLS/Cashu state. `SharedPreferences` via `Storage` for settings; `FlutterSecureStorage` via `SecureStorage` for keys/mnemonics.

**Encryption strategy pattern:** `BaseChatService` abstract class → `SignalChatService` (1:1), `MlsGroupService` (groups), `Nip4ChatService` (legacy). Dispatch based on `Room.encryptMode`.

**Nostr message flow:** `WebsocketService` → multiple `RelayWebsocket` instances → events queued in `NostrAPI.nostrEventQueue` (async sequential) → routed to appropriate chat service.

**Rust FFI:** `flutter_rust_bridge` v2.11.1 generates Dart bindings. Each Rust module (`api_signal.rs`, `api_mls.rs`, `api_nostr.rs`, `api_cashu.rs`) has a `lazy_static` Mutex-guarded store with dedicated Tokio runtime. Import with aliases:

```dart
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;
```

### NIP-17/44/59 Implementation (Critical)

**Message encryption layers** (innermost to outermost):

1. **Rumor** (kind 14) — actual message content + metadata
2. **Seal** (kind 13) — encrypted rumor with NIP-44, reveals sender to recipient
3. **Gift Wrap** (kind 1059) — encrypted seal with random key, timestamp tweaked ±2 days

**Two signing paths:**

- **Amber Signer** (Android external signer): Uses `SignerService.getNip59EventString()` — single signature via Amber API
- **Rust FFI** (native keys): Uses `rust_nostr.createGiftJson()` — all encryption/signing in Rust

**Sender Copy architecture** (currently disabled, reserved for future multi-device sync):

- `SignerService.getNip59EventStringsWithSenderCopy()` creates TWO gift wraps per message
- One encrypted for receiver (DH with receiver's pubkey)
- One encrypted for sender (DH with sender's own pubkey, enables multi-device retrieval)
- `sendAndSaveNostrEventWithSenderCopy()` handles dual-event sending
- When enabled: Amber signs twice, both events sent to relays with same rumor ID for deduplication

## Key Conventions

### Service singletons — always use this pattern:

```dart
class FooService extends BaseChatService {
  FooService._();
  static FooService? _instance;
  static FooService get instance => _instance ??= FooService._();
}
```

### File naming:

| Type        | Pattern               | Example                          |
| ----------- | --------------------- | -------------------------------- |
| Service     | `xxx.service.dart`    | `room.service.dart`              |
| Controller  | `xxx.controller.dart` | `chat.controller.dart`           |
| Page/Screen | `xxx_page.dart`       | `chat_setting_contact_page.dart` |
| Generated   | `xxx.g.dart`          | `room.g.dart`                    |

### Isar models use `@Collection` with code generation (`part '*.g.dart'`). Enums use `@Enumerated(EnumType.ordinal32)`. Embedded objects live in `models/embedded/`.

### Error handling pattern:

```dart
try {
  // logic
} catch (e, s) {
  logger.e('Description', error: e, stackTrace: s);
  EasyLoading.showError(Utils.getErrorMessage(e));
}
```

**Why this pattern:** Centralized error logging with stack traces + user-facing toast notifications. `Utils.getErrorMessage()` extracts localized error messages from exceptions.

### Import order: Dart core → Flutter/framework → third-party → project (`package:keychat/`) → Rust FFI (aliased).

### Comments & Documentation

**MANDATORY: All comments and documentation MUST be in English.**

- Use `///` for public API documentation (classes, methods, functions)
- Use `//` for inline implementation comments
- **Always add doc comments** when creating new functions or modifying existing ones
- Explain the "why" not just the "what" in comments

**Examples:**

```dart
// ✅ CORRECT - English comments
/// Sends a NIP-17 encrypted message to the specified room.
///
/// Creates a gift-wrapped event with three encryption layers:
/// 1. Rumor (kind 14) - actual message content
/// 2. Seal (kind 13) - encrypted with NIP-44
/// 3. Gift Wrap (kind 1059) - encrypted with random key
///
/// Returns [SendMessageResponse] containing the event ID and delivery status.
/// Throws [RoomNotFoundException] if the room does not exist.
Future<SendMessageResponse> sendNip17Message(Room room, String content) async {
  // Validate room is enabled before attempting to send
  if (room.status != RoomStatus.enabled) {
    throw RoomNotEnabledException();
  }

  // Use Amber signer for external key management
  if (identity.isFromSigner) {
    encryptedEvent = await SignerService.instance.getNip59EventString(
      content: content,
      from: identity.secp256k1PKHex,
      to: room.toMainPubkey,
    );
  }
  // ...
}

```

**Variable and function naming:**

```dart
// ✅ CORRECT - English names
Future<void> sendEncryptedMessage() async { }
String encryptedEventToReceiver = '';
bool isMessageSent = false;

// ❌ WRONG - Non-English names
Future<void> faXiaoXi() async { }  // Don't use Pinyin
String jiamiShijian = '';           // Don't use transliterations
```

### Type safety (Dart 3.9+)

Always specify generic types explicitly to avoid inference errors:

```dart
// ✅ Correct
final tags = receiverEvent['tags'].whereType<List<dynamic>>();
final receiverRumorTag = tags.firstWhere(
  (List<dynamic> tag) => tag.isNotEmpty && tag[0] == 'e',
  orElse: () => <dynamic>[''],
) as List<dynamic>;

// ❌ Wrong - causes "Conditions must have a static type of 'bool'" error
final tags = receiverEvent['tags'].whereType<List>();
final receiverRumorTag = tags.firstWhere(
  (tag) => tag.isNotEmpty && tag[0] == 'e',
  orElse: () => [''],
);
```

## Build & Dev Commands

```bash
melos bootstrap                  # Install all package dependencies
melos run lint:all               # Analyze + format (run before committing)
melos run build:runner           # Regenerate Isar schemas / JSON serialization
melos run intl:generate          # Regenerate i18n
melos run test:all               # Run all tests
melos run test:flutter           # Flutter tests only
melos run pod:install            # Update iOS/macOS CocoaPods

# After modifying Rust code:
cd packages/keychat_rust_ffi_plugin
flutter_rust_bridge_codegen generate
# Or use Makefile: make g2

# Run the app:
cd packages/app && flutter run -d <device>

# Run specific test file:
flutter test test/unit/nip17_sender_copy_test.dart
```

## Security Rules

- **No dangerous deletions**: Never execute `rm -rf`, `git clean -fd`, `git reset --hard` without explicit user confirmation
- **No access to sensitive files**: Do not read or modify `.env`, `*.key`, `*.pem`, `credentials.*`, `secrets.*` files
- **Confirm destructive operations**: Always ask before deleting files, clearing data, or resetting state
- **No external transmission of secrets**: Never send keys, passwords, tokens to external services or print to logs

## Key Files & Directories

- `packages/app/lib/main.dart` — boot sequence, DI registration order matters
- `packages/app/lib/global.dart` — `KeychatGlobal` constants (relays, mints, key pools, DB names)
- `packages/app/lib/service/` — ~28 service singletons; `room.service.dart` is the central dispatcher
- `packages/app/lib/controller/home.controller.dart` — "God controller" for app lifecycle, identity switching
- `packages/app/lib/nostr-core/nostr.dart` — `NostrAPI` event queue processing
- `packages/app/lib/nostr-core/relay_websocket.dart` — per-relay WebSocket (max 20 subs, 120 pubkeys/batch)
- `packages/app/lib/models/db_provider.dart` — manual DB migration (`performMigrationIfNeeded`)
- `packages/keychat_rust_ffi_plugin/rust/src/` — Rust crypto implementations (Signal, MLS, Nostr, Cashu)

## Nostr NIPs Implemented

NIP-01, NIP-06, NIP-07, NIP-17, NIP-19, NIP-44, NIP-47, NIP-55, NIP-59, NIP-B7

## Code Patterns & Conventions

### Documentation Rules

- **Add function comments during iterations**: When modifying or reviewing code, add missing documentation comments to functions
- **Use English for all comments**: All code comments, documentation, and docstrings must be in English
- **Use Dart doc comments**: Use `///` for public APIs, `//` for implementation details

```dart
/// Sends a message to the specified room.
///
/// Returns [SendMessageResponse] containing the message ID and status.
/// Throws [RoomNotFoundException] if the room does not exist.
Future<SendMessageResponse> sendMessage(Room room, String content) async {
  // Validate room status before sending
  if (room.status != RoomStatus.enabled) {
    throw RoomNotEnabledException();
  }
  // ...
}
```

### Service Singleton Pattern

```dart
class XxxService extends BaseChatService {
  XxxService._();
  static XxxService? _instance;
  static XxxService get instance => _instance ??= XxxService._();
}
```

### Controller Pattern (GetX)

```dart
class XxxController extends GetxController {
  // Reactive variables
  RxList<Message> messages = <Message>[].obs;
  Rx<Room> roomObs = Room(...).obs;
  RxBool isLoading = false.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
  }
}
```

- Use `Get.find<T>()` to get Controller
- Use `.obs` to create reactive variables, `.value` to access value
- Use `Obx(() => ...)` in UI to listen for changes

### Model Pattern (Isar)

```dart
@Collection(ignore: {'props', 'runtimeField'})
class Room extends Equatable {
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('identityId')])
  late String toMainPubkey;

  @Enumerated(EnumType.ordinal32)
  late RoomType type;

  final mykey = IsarLink<Mykey>();

  @override
  List<Object?> get props => [id, toMainPubkey];
}
```

### JSON Serialization

```dart
@JsonSerializable()
class XxxModel {
  const XxxModel({required this.field, this.optionalField});

  factory XxxModel.fromJson(Map<String, dynamic> json) =>
      _$XxxModelFromJson(json);

  final String field;
  @JsonKey(includeIfNull: false)
  final String? optionalField;

  Map<String, dynamic> toJson() => _$XxxModelToJson(this);
}
```

### Naming Conventions

| Type            | Pattern               | Example                          |
| --------------- | --------------------- | -------------------------------- |
| Service file    | `xxx.service.dart`    | `room.service.dart`              |
| Controller file | `xxx.controller.dart` | `chat.controller.dart`           |
| Model file      | `xxx.dart`            | `room.dart`                      |
| Page file       | `xxx_page.dart`       | `chat_setting_contact_page.dart` |
| Generated file  | `xxx.g.dart`          | `room.g.dart`                    |

### Import Order

```dart
// 1. Dart core libraries
import 'dart:async';
import 'dart:convert';

// 2. Flutter/framework
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// 3. Third-party packages
import 'package:isar_community/isar.dart';

// 4. Project packages
import 'package:keychat/service/room.service.dart';

// 5. Rust FFI (use aliases)
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
```

### Error Handling

```dart
try {
  // Business logic
} catch (e, s) {
  logger.e('Description', error: e, stackTrace: s);
  EasyLoading.showError(Utils.getErrorMessage(e));
}
```

### Common Utilities

- `logger.i/d/e()` - Logging
- `EasyLoading.showToast/showSuccess/showError()` - Toast messages
- `Utils.getErrorMessage(e)` - Extract error message
- `Get.dialog()` / `Get.to()` / `Get.back()` - Navigation and dialogs

## After Code Changes

```bash
# Regenerate after modifying models
melos run build:runner

# Regenerate Dart bindings after modifying Rust code
cd packages/keychat_rust_ffi_plugin
flutter_rust_bridge_codegen generate

# Check before committing
melos run lint:all
```

## Documentation for Complex Changes

**Temporary/Working Documents (`docs_local/`):**

- Complex bug fixes and performance issues: create `{category}/{issue-name}/DIAGNOSIS.md` and `FIXES.md`
- Code plans, design drafts, investigation notes, and other working documents
- Can be in any language
- **Organize with subdirectories by category** (e.g., `performance/`, `bugs/`, `features/`)

**Formal Documentation (`docs/`):**

- Architecture design, complex features, design decisions, and security-related documentation
- **Must be written in English**
- **Organize with subdirectories by topic** (e.g., `architecture/`, `protocols/`, `security/`)

**Commit Log Summary (`Changelog.md`):**

- Write commit log summaries to `Changelog.md` in the root directory
- Keep entries **concise and well-formatted**
