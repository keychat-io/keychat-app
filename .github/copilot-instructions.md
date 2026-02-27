# Keychat — AI Coding Agent Instructions

## Project Overview

Keychat is a privacy-focused secure chat super-app for Bitcoiners. It's a **Flutter + Rust monorepo** managed by **Melos 7.3.0**, using **FVM** (Flutter 3.38.2, Dart ≥3.9.0).

Three packages: `packages/app` (main Flutter app), `packages/keychat_ecash` (Bitcoin ecash wallet UI/logic), `packages/keychat_rust_ffi_plugin` (Rust FFI for crypto — Signal, MLS, Nostr, Cashu).

## Architecture

**State management:** GetX exclusively — `Get.put`/`Get.lazyPut` for DI, `.obs` reactive variables, `Obx()` in UI, `Get.find<T>()` for lookup.

**Database:** Isar Community 3.3.0 (NoSQL) for app data; SQLite (via Rust) for Signal/MLS/Cashu state. `SharedPreferences` via `Storage` for settings; `FlutterSecureStorage` via `SecureStorage` for keys/mnemonics.

**Encryption strategy pattern:** `BaseChatService` abstract class → `SignalChatService` (1:1), `MlsGroupService` (groups), `Nip4ChatService` (legacy). Dispatch based on `Room.encryptMode`.

**Nostr message flow:** `WebsocketService` → multiple `RelayWebsocket` instances → events queued in `NostrAPI.nostrEventQueue` (async sequential) → routed to appropriate chat service.

**Rust FFI:** `flutter_rust_bridge` v2 generates Dart bindings. Each Rust module (`api_signal.rs`, `api_mls.rs`, `api_nostr.rs`, `api_cashu.rs`) has a `lazy_static` Mutex-guarded store with dedicated Tokio runtime. Import with aliases:

```dart
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;
```

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

### Import order: Dart core → Flutter/framework → third-party → project (`package:keychat/`) → Rust FFI (aliased).

### Comments: English only. Use `///` for public APIs, `//` for implementation. Add missing doc comments when modifying existing code.

## Build & Dev Commands

```bash
melos bootstrap                  # Install all package dependencies
melos run lint:all               # Analyze + format (run before committing)
melos run build:runner           # Regenerate Isar schemas / JSON serialization
melos run intl:generate          # Regenerate i18n
melos run test:all               # Run all tests
melos run pod:install            # Update iOS/macOS CocoaPods

# After modifying Rust code:
cd packages/keychat_rust_ffi_plugin
flutter_rust_bridge_codegen generate

# Run the app:
cd packages/app && flutter run -d <device>
```

## Key Files & Directories

- `packages/app/lib/main.dart` — boot sequence, DI registration order matters
- `packages/app/lib/global.dart` — `KeychatGlobal` constants (relays, mints, key pools, DB names)
- `packages/app/lib/service/` — ~28 service singletons; `room.service.dart` is the central dispatcher
- `packages/app/lib/controller/home.controller.dart` — "God controller" for app lifecycle, identity switching
- `packages/app/lib/nostr-core/nostr.dart` — `NostrAPI` event queue processing
- `packages/app/lib/nostr-core/relay_websocket.dart` — per-relay WebSocket (max 20 subs, 120 pubkeys/batch)
- `packages/app/lib/models/db_provider.dart` — manual DB migration (`performMigrationIfNeeded`)
- `packages/keychat_rust_ffi_plugin/rust/src/` — Rust crypto implementations (Signal, MLS, Nostr, Cashu)
