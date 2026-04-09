# Flutter Test Strategy Design

## Context

Keychat is a secure chat app built on Bitcoin Ecash, Nostr, Signal Protocol, and MLS. The codebase has ~260 Dart files with 13 existing test files covering utilities and some protocol logic. After a recent large-scale field rename refactoring (50 files), there is a clear need for automated tests to prevent regressions and build confidence for future changes.

**Goals:**
1. Prevent regression from refactoring (especially JSON serialization backward compat)
2. Build test coverage for core business logic
3. Establish CI quality gates (future)

**Constraints:**
- No CI/CD currently — tests run locally via `flutter test`
- Prefer "few but precise" tests — each test has a clear reason to exist
- Phased approach — start without mocking, add mocktail later
- Must not break existing test infrastructure

## Architecture: 3-Phase Test Pyramid

```
Phase 3: Service Integration Tests (with mocktail)
  - identity.service, signal_chat.service, room.service
  - Mock Isar DB, Rust FFI, GetX controllers

Phase 2: Protocol & Utility Tests (pure logic)
  - NostrEventModel, SignerService, signal_chat_util
  - extractSingleUrl, timestamp randomization

Phase 1: Model Serialization Tests (pure data)  <-- START HERE
  - QRUserModel, MsgReply, RoomProfile, NostrEventModel
  - JSON backward compat, roundtrip verification
```

## Phase 1: Model JSON Serialization Tests

### Test Files

```
test/
  models/
    qrcode_user_model_test.dart      # QR code model backward compat
    msg_reply_test.dart               # Reply model backward compat
    room_profile_test.dart            # Room profile backward compat
    nostr_event_model_test.dart       # Nostr event serialization
    filter_test.dart                  # Subscription filter serialization
    msg_file_info_test.dart           # File/audio metadata (extend existing)
    room_member_test.dart             # Room member serialization
    keychat_message_test.dart         # Hello message field names
```

### Test Cases Per Model

#### QRUserModel (highest priority)

```
group('QRUserModel JSON serialization')
  test('fromJson with new field names (nostrIdentityKey, signalIdentityKey, receiveAddress)')
  test('fromJson with legacy field names (pubkey, curve25519PkHex, onetimekey)')
  test('fromJson with legacy signal key names (signedId, signedPublic, prekeyId, prekeyPubkey)')
  test('toJson outputs both new and legacy field names')
  test('fromShortString -> toShortStringForQrcode roundtrip preserves data')
  test('fromJson -> toJson -> fromJson roundtrip preserves all fields')
```

#### MsgReply

```
group('MsgReply JSON serialization')
  test('fromJson with new field names (eventId, userId, userName)')
  test('fromJson with legacy field names (id, user)')
  test('toJson outputs both new and legacy field names')
  test('fromJson -> toJson roundtrip preserves data')
  test('nullable fields handled correctly (eventId=null, userId=null)')
```

#### RoomProfile

```
group('RoomProfile JSON serialization')
  test('fromJson with new field name (groupId)')
  test('fromJson with legacy field name (oldToRoomPubKey)')
  test('toJson outputs both groupId and oldToRoomPubKey')
  test('fromJson -> toJson roundtrip preserves data')
```

#### NostrEventModel

```
group('NostrEventModel')
  test('fromJson constructs event correctly')
  test('toJson serializes all fields')
  test('fromJson -> toJson roundtrip')
  test('deserialize from ["EVENT", json] array format')
  test('deserialize from ["EVENT", subId, json] array format')
  test('serialize produces correct array format')
  test('isSignal returns true for signal-encrypted events')
  test('isNip4 returns true for NIP-04 encrypted events')
  test('encryptType derives correctly from kind and content')
  test('getTagsByKey extracts tag values')
  test('getTagByKey returns first matching tag')
```

#### Filter

```
group('Filter')
  test('fromJson parses all filter fields')
  test('toJson omits null fields')
  test('fromJson -> toJson roundtrip')
  test('empty filter serializes to empty map')
```

#### RoomMember

```
group('RoomMember JSON serialization')
  test('fromJson -> toJson roundtrip')
  test('excludes JsonKey(includeToJson: false) fields from output')
```

#### MsgFileInfo

```
group('MsgFileInfo audio metadata')
  test('audio duration and amplitudes survive fromJson -> toJson')
```

#### KeychatMessage

```
group('KeychatMessage hello message')
  test('setHelloMessage uses correct field names (nostrIdentityKey, signalIdentityKey, receiveAddress)')
```

### Test Pattern

All tests follow the same structure:

```dart
test('description', () {
  // Arrange: create JSON map with known values
  final json = { ... };

  // Act: deserialize
  final model = Model.fromJson(json);

  // Assert: verify fields
  expect(model.field, equals(expectedValue));

  // Roundtrip: serialize back and verify
  final outputJson = model.toJson();
  expect(outputJson['key'], equals(expectedValue));
});
```

## Phase 2: Protocol & Utility Tests

### Test Files

```
test/
  unit/
    signer_service_test.dart          # Timestamp randomization
    signal_chat_util_test.dart        # Message signing payload format
  utils_test.dart                     # Extend existing: extractSingleUrl
  nostr-core/
    nostr_utils_test.dart             # Escape/unescape functions
```

### Key Test Cases

- `_randomizedTimestamp()`: output is within [now - 2 days, now]
- `getToSignMessage()`: format is `Keychat-<nostrId>-<signalId>-<time>`
- `extractSingleUrl()`: detects single URLs, rejects multi-URL or non-URL text
- `addEscapeChars()`: correctly escapes quotes and newlines
- `_isUrl()`, `_isLightningInvoice()`, `_isNostrPubkey()`: pattern matching validation

## Phase 3: Service Layer Tests (with mocktail)

### Prerequisites

Add to `pubspec.yaml` dev_dependencies:
```yaml
mocktail: ^1.0.4
```

### Test Files

```
test/
  service/
    room_service_test.dart            # checkRoomStatus logic
    qrscan_service_test.dart          # URL/invoice/pubkey detection
    chatx_service_test.dart           # Key pair construction
    identity_service_test.dart        # Inbox key lifecycle (mock Isar)
    signal_chat_service_test.dart     # Prekey processing (mock Rust FFI)
```

### Mock Strategy

```dart
// Mock Isar database
class MockIsar extends Mock implements Isar {}

// Mock Rust FFI
class MockRustSignal extends Mock implements RustSignalApi {}

// Mock GetX controller
class MockHomeController extends Mock implements HomeController {}
```

Only mock at boundaries — Isar, Rust FFI, network. Business logic inside services is tested as-is.

## Phase 4 (Future): Risk-Based Integration Tests

- Signal session establishment: prekey exchange -> encrypted message roundtrip
- MLS group key exchange: create group -> add member -> send message
- Ecash token: create -> send -> receive -> redeem flow

Requires Rust FFI to be available in test environment.

## Phase 5 (Future): CI Quality Gates

### GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Flutter Tests
on: [pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.2'
      - run: melos bootstrap
      - run: melos run test:all
      - run: melos run analyze
```

### Melos Test Scripts

```yaml
# melos.yaml additions
scripts:
  test:unit:
    run: flutter test test/ --no-pub
    packageFilters:
      scope: keychat
  test:coverage:
    run: flutter test --coverage test/
    packageFilters:
      scope: keychat
```

## Running Tests

```bash
# All tests
melos run test:all

# Single test file
flutter test test/models/qrcode_user_model_test.dart

# With verbose output
flutter test --reporter expanded test/models/
```

## Success Criteria

- Phase 1: All 8 model test files pass, ~40 test cases, zero failures
- Phase 2: Protocol and utility tests pass, ~20 additional test cases
- Phase 3: Service tests with mocks pass, ~15 additional test cases
- All phases: `flutter analyze` reports zero errors
- Future: CI blocks PRs with failing tests
