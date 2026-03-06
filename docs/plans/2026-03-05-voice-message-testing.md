# Voice Message — Testing Guide

## Unit Tests

Run all voice message tests:
```bash
cd packages/app && flutter test test/models/
```

### Test files

| File | Tests | What it covers |
|------|-------|----------------|
| `test/models/msg_file_info_audio_test.dart` | 8 | MsgFileInfo audio field serialization, round-trip, edge cases |
| `test/models/message_media_type_test.dart` | 5 | MessageMediaType.audio enum correctness and ordering |

### Test coverage

- **MsgFileInfo serialization:** audioDuration + amplitudeSamples round-trip, null handling, zero duration, empty samples, max duration (60s / 600 samples), coexistence with non-audio fields, fromJson with extra fields
- **MessageMediaType enum:** audio value exists, correct name, correct ordinal position, all original values preserved

## Manual Testing Checklist

### Prerequisites

```bash
cd packages/app
flutter devices                    # pick a device
flutter run -d <device-id>
```

### Recording

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 1 | Mic button visible | Open any 1:1 chat | Mic icon appears between text field and send/+ button |
| 2 | Long-press starts recording | Long-press the mic button | Red recording indicator replaces text field, timer starts at 00:00 |
| 3 | Timer counts up | Hold for 5+ seconds | Timer increments every second (00:01, 00:02, ...) |
| 4 | Release sends | Hold 3 seconds, release | Recording indicator disappears, voice message bubble appears in chat |
| 5 | Short press ignored | Tap mic briefly (< 1 second) | Nothing sent, no error |
| 6 | Slide to cancel | Hold, slide finger/cursor left > 100px | Recording cancelled, no message sent, indicator disappears |
| 7 | Cancel hint visible | Start recording | "Slide to cancel" text shown on right side of indicator |
| 8 | 60s auto-send | Hold for 60 seconds | Automatically sends at 60 second limit |
| 9 | Permission denied | Deny mic permission when prompted | SnackBar shows "Microphone permission required" with Settings link |

### Playback

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 10 | Play button | Tap play icon on a voice bubble | Audio starts playing, icon changes to pause, progress bar moves |
| 11 | Pause | Tap pause icon while playing | Audio pauses, icon returns to play |
| 12 | Resume | Tap play after pause | Audio resumes from pause position |
| 13 | Progress bar | Play a message | Progress bar fills from left to right during playback |
| 14 | Duration display | Look at voice bubble | Shows total duration (e.g., 00:03), switches to elapsed during playback |
| 15 | Auto-stop on complete | Let a message play to the end | Icon returns to play, progress resets |
| 16 | Switch message | Play message A, then tap play on message B | Message A stops, message B starts |
| 17 | Leave chat stops playback | Start playback, then navigate back | Audio stops |

### Download (receiving voice messages)

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 18 | Download on tap | Receive a voice message from another user, tap play | File downloads and decrypts, then plays |
| 19 | Retry on failure | Tap play while offline | No crash; tap again when online to retry |

### Edge Cases

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 20 | Delete voice message | Long-press voice bubble, select Delete | Message removed, local audio file cleaned up |
| 21 | Forward voice message | Long-press voice bubble, select Forward | Forward dialog appears with room selection |
| 22 | File info section | Long-press voice bubble, check details | Shows file info (size, type) |
| 23 | Multiple chats | Record in chat A, switch to chat B | No stale recording state in chat B |
| 24 | Rapid record/cancel | Start and cancel recording rapidly 5 times | No crash, no leaked temp files |

### Platform-Specific

| Platform | Extra checks |
|----------|-------------|
| **iOS** | Mic permission prompt appears on first use; works in both portrait/landscape |
| **Android** | RECORD_AUDIO permission handled; works on API 21+ |
| **macOS** | audio-input entitlement works; long-press gesture works with trackpad |

## Automated Test Run

```bash
# All model tests
flutter test test/models/

# Full project analysis (no errors expected)
flutter analyze lib/

# Full lint check
melos run lint:all
```
