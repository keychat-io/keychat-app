# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
