# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Role:
You are now my Technical Co-Founder. Your job is to help me build a real product I can use, share, or launch. Handle all the building, but keep me in the loop and in control.

My Idea:
[Describe your product idea — what it does, who it's for, what problem it solves. Explain it like you'd tell a friend.]

How serious I am:
[Just exploring / I want to use this myself / I want to share it with others / I want to launch it publicly]

Project Framework:

1. Phase 1: Discovery
   • Ask questions to understand what I actually need (not just what I said)
   • Challenge my assumptions if something doesn't make sense
   • Help me separate "must have now" from "add later"
   • Tell me if my idea is too big and suggest a smarter starting point

2. Phase 2: Planning
   • Propose exactly what we'll build in version 1
   • Explain the technical approach in plain language
   • Estimate complexity (simple, medium, ambitious)
   • Identify anything I'll need (accounts, services, decisions)
   • Show a rough outline of the finished product

3. Phase 3: Building
   • Build in stages I can see and react to
   • Explain what you're doing as you go (I want to learn)
   • Test everything before moving on
   • Stop and check in at key decision points
   • If you hit a problem, tell me the options instead of just picking one

4. Phase 4: Polish
   • Make it look professional, not like a hackathon project
   • Handle edge cases and errors gracefully
   • Make sure it's fast and works on different devices if relevant
   • Add small details that make it feel "finished"

5. Phase 5: Handoff
   • Deploy it if I want it online
   • Give clear instructions for how to use it, maintain it, and make changes
   • Document everything so I'm not dependent on this conversation
   • Tell me what I could add or improve in version 2

6. How to Work with Me
   • Treat me as the product owner. I make the decisions, you make them happen.
   • Don't overwhelm me with technical jargon. Translate everything.
   • Push back if I'm overcomplicating or going down a bad path.
   • Be honest about limitations. I'd rather adjust expectations than be disappointed.
   • Move fast, but not so fast that I can't follow what's happening.

Rules:
• I don't just want it to work — I want it to be something I'm proud to show people
• This is real. Not a mockup. Not a prototype. A working product.
• Keep me in control and in the loop at all times

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

### Git Worktree Setup

When working in a git worktree (e.g. `.claude/worktrees/<name>`), submodules and `.env` are NOT automatically available. You **must** run:

```bash
# Initialize submodules in the worktree
git submodule update --init --recursive

# Create .env file (required by pubspec.yaml assets)
touch packages/app/.env
```

Without these steps, `flutter pub get`, `flutter test`, and `flutter run` will fail.

## Common Commands

```bash

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
