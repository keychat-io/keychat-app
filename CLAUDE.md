# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Security Rules

- **No dangerous deletions**: Do not execute destructive commands like `rm -rf`, `git clean -fd`, `git reset --hard`
- **No access to sensitive files**: Do not read or modify `.env`, `*.key`, `*.pem`, `credentials.*`, `secrets.*` files
- **Confirm before destructive operations**: Always ask user confirmation before deleting files, clearing data, or resetting state
- **No external transmission of secrets**: Never send keys, passwords, tokens, or private keys to external services or print them to logs

## Project Overview

Keychat is a secure chat application built on:
- **Bitcoin Ecash (Cashu)** - Micropayments/stamps for message delivery
- **Nostr Protocol** - Decentralized message delivery and storage
- **Signal Protocol** - End-to-end encryption for 1:1 chats
- **MLS Protocol** - Encryption for large group messaging

The app uses a postal system metaphor: messages are "stamped" with Bitcoin ecash and sent to Nostr relays, which collect the ecash and deliver messages to recipients.

## Development Setup

```bash
# Clone with submodules
git submodule update --init --recursive

# Install melos
dart pub global activate melos 7.3.0

# Bootstrap all packages
melos bootstrap

# Copy and configure environment (for FCM push notifications)
cp packages/app/.env.example packages/app/.env

# Run the app
cd packages/app
flutter devices
flutter run -d <device>
```

**Flutter version**: 3.38.2 (managed via FVM - see `.fvmrc`)

## Common Commands

```bash
# Build
melos run build:ios
melos run build:android
melos run build:macos
melos run build:win
melos run build:linux

# Test
melos run test:all           # All tests
melos run test:flutter       # Flutter tests only
flutter test test/foo.dart   # Single test file

# Code quality
melos run lint:all           # Analyze + format
melos run analyze            # Dart analyzer
dart format --set-exit-if-changed .

# Code generation (Isar models, JSON serialization)
melos run generate:all
melos run build:runner       # App build_runner only

# Internationalization
melos run intl:generate

# iOS/macOS pods
melos run pod:install
```

## Project Structure

```
packages/
├── app/                          # Main Flutter application
│   ├── lib/
│   │   ├── main.dart             # Entry point
│   │   ├── controller/           # GetX controllers (state management)
│   │   ├── service/              # Business logic services
│   │   ├── page/                 # UI screens
│   │   ├── models/               # Data models (Isar DB entities)
│   │   ├── nostr-core/           # Nostr protocol implementation
│   │   └── widgets/              # Reusable UI components
│   └── test/                     # Unit tests
│
├── keychat_ecash/                # Bitcoin ecash integration
│
└── keychat_rust_ffi_plugin/      # Rust FFI plugin
    ├── rust/src/
    │   ├── api_cashu.rs          # Ecash (Cashu) API
    │   ├── api_nostr.rs          # Nostr protocol API
    │   ├── api_signal.rs         # Signal protocol API
    │   └── api_mls.rs            # MLS protocol API
    └── lib/                      # Generated Dart bindings
```

## Architecture

**State Management**: GetX
**Database**: Isar (NoSQL)
**FFI Bridge**: flutter_rust_bridge v2.11.1
**Networking**: Custom WebSocket service for Nostr relays

**Key Services** (`packages/app/lib/service/`):
- `signal_chat.service.dart` - Signal protocol encryption for 1:1 chats
- `mls_group.service.dart` - MLS protocol for group chats
- `websocket.service.dart` - Nostr relay connections
- `chat.service.dart` - Message handling and routing

**Rust APIs** (`packages/keychat_rust_ffi_plugin/rust/src/`):
- Cashu ecash operations
- Nostr event signing/verification
- Signal protocol state machines
- MLS group key management

## Building Rust Native Libraries

```bash
cd packages/keychat_rust_ffi_plugin

# Install flutter_rust_bridge codegen
cargo install flutter_rust_bridge_codegen@2.11.1

# Build for target platform
rustup target add aarch64-apple-ios          # iOS
rustup target add aarch64-linux-android      # Android
rustup target add x86_64-unknown-linux-gnu   # Linux
rustup target add x86_64-pc-windows-msvc     # Windows

cargo build --target <target> --release --target-dir target
```

**Linux dependencies**: `apt install protobuf-compiler libsecret-1-dev`

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

| Type | Pattern | Example |
|------|---------|---------|
| Service file | `xxx.service.dart` | `room.service.dart` |
| Controller file | `xxx.controller.dart` | `chat.controller.dart` |
| Model file | `xxx.dart` | `room.dart` |
| Page file | `xxx_page.dart` | `chat_setting_contact_page.dart` |
| Generated file | `xxx.g.dart` | `room.g.dart` |

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
