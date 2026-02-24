---
name: rust-build
description: Build Rust native libraries for the FFI plugin
argument-hint: "[target]"
disable-model-invocation: true
allowed-tools: Bash(cargo *), Bash(rustup *)
---

Build the Rust native libraries for the keychat_rust_ffi_plugin.

## Arguments
- `$ARGUMENTS` - Target platform: ios, android, linux, windows, macos

## Prerequisites

Ensure flutter_rust_bridge codegen is installed:
```bash
cargo install flutter_rust_bridge_codegen@2.11.1
```

For Linux, install system dependencies:
```bash
apt install protobuf-compiler libsecret-1-dev
```

## Target Setup and Build Commands

| Platform | Target | Setup & Build |
|----------|--------|---------------|
| iOS | aarch64-apple-ios | `rustup target add aarch64-apple-ios && cargo build --target aarch64-apple-ios --release` |
| Android | aarch64-linux-android | `rustup target add aarch64-linux-android && cargo build --target aarch64-linux-android --release` |
| Linux | x86_64-unknown-linux-gnu | `rustup target add x86_64-unknown-linux-gnu && cargo build --target x86_64-unknown-linux-gnu --release` |
| Windows | x86_64-pc-windows-msvc | `rustup target add x86_64-pc-windows-msvc && cargo build --target x86_64-pc-windows-msvc --release` |
| macOS | aarch64-apple-darwin | `rustup target add aarch64-apple-darwin && cargo build --target aarch64-apple-darwin --release` |

## Workflow

1. Change to the Rust plugin directory:
   ```bash
   cd packages/keychat_rust_ffi_plugin/rust
   ```

2. If no target specified, ask which platform to build for

3. Add the rustup target if not already added:
   ```bash
   rustup target add <target>
   ```

4. Build the library:
   ```bash
   cargo build --target <target> --release --target-dir target
   ```

5. Report build success or any errors

## Regenerating Dart Bindings

After modifying Rust API files, regenerate the Dart bindings:
```bash
cd packages/keychat_rust_ffi_plugin
flutter_rust_bridge_codegen generate
```
