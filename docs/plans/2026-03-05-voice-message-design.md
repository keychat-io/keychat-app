# Voice Message Feature Design

**Date:** 2026-03-05
**Status:** Approved

## Overview

Add voice message support to Keychat, allowing users to record and send voice messages using a press-and-hold interaction model. Messages are end-to-end encrypted using the existing file encryption infrastructure.

## Requirements

- **Interaction:** Press-and-hold microphone button to record, release to send (WeChat-style)
- **Platforms:** iOS, Android, macOS
- **Duration limit:** 60 seconds maximum
- **Playback UI:** Simple progress bar + duration display (no waveform in v1, but extensible)
- **Cancellation:** Slide left > 100px while holding to cancel

## Technical Approach

**Packages:**
- `record: ^5.2.0` — cross-platform audio recording (iOS/Android/macOS)
- `just_audio: ^0.9.42` — audio playback with precise progress control

## Data Model Changes

### MessageMediaType (enum)
Add new value to existing enum in `packages/app/lib/models/`:
```dart
enum MessageMediaType {
  // ...existing values...
  audio,  // new
}
```

### MsgFileInfo (existing model, extend with 2 optional fields)
```dart
// Audio duration in seconds
int? audioDuration;

// Amplitude samples recorded every 100ms (values 0.0–1.0, max 600 entries)
// Empty in v1, populated in future waveform update
List<double>? amplitudeSamples;
```

No new models required. Reuses existing file info structure.

## UI Components

### New files
```
packages/app/lib/
├── service/
│   └── audio_message.service.dart       # Core record/upload/playback logic
├── page/chat/widgets/
│   ├── voice_record_button.dart         # Long-press mic button
│   ├── voice_record_indicator.dart      # Recording state bar (timer + cancel hint)
│   └── voice_message_bubble.dart        # Playback bubble (progress bar + duration)
```

### Chat input bar layout
Normal state:
```
[🎤] [Text input field...............] [Send/+]
```

Recording state (after press-and-hold):
```
[⌨] [● Recording... 00:03    ← slide to cancel]  [release to send]
```

### Voice message bubble (received/sent)
```
[▶] ──────────────── 0:08
```
- Tap to play/pause
- Progress bar updates in real time
- Shows total duration
- Only one voice message plays at a time (switching auto-stops previous)

## Architecture

### AudioMessageService responsibilities

**Recording flow:**
1. Request microphone permission via `permission_handler`
2. Start recording via `record` package (AAC-LC, 32kbps)
3. Poll amplitude every 100ms via `_recorder.getAmplitude()`, normalize dBFS to 0.0-1.0
4. On release: stop recording, get file path
5. Call `FileService.handleSendAudioFile()` which encrypts, uploads, embeds audio metadata, and sends
6. `sendMessage()` called with `mediaType: MessageMediaType.audio`

**Playback flow:**
1. Check if audio file is already downloaded locally
2. If not: download + decrypt via existing file download logic
3. Play via `just_audio`
4. Global singleton playback state — switching tracks auto-stops current

### Changes to existing code
- `FileService` — added `handleSendAudioFile()` to embed `audioDuration`/`amplitudeSamples` before sending
- `RoomUtil.getTextViewWidget` — added `MessageMediaType.audio` case routing to `VoiceMessageBubble`
- `message_widget.dart` — added `audio` to delete, file-info, and forward checks
- `ChatController.onClose` — stops playback when leaving chat

### Unchanged (reused as-is)
- `FileService.encryptToSendFile()` — encrypted upload
- `FileService.downloadForMessage()` — download + decrypt for playback
- `sendMessage()` — pass `mediaType: audio`

## Error Handling

| Scenario | Handling |
|----------|----------|
| Microphone permission denied | Toast with link to system settings |
| Recording < 1 second | Discard silently, no send |
| Upload failure | Message shows failed state, tap to retry (reuses existing retry logic) |
| Download failure | Bubble shows "tap to download" state |
| Multiple voice messages received | Only play on tap, no auto-play |
| Switch chat room | Auto-stop current playback |
| App goes to background during recording | Stop recording, discard, no send |
| macOS device has no microphone | Mic button disabled/hidden |

## Future Extensibility (v2)

The `amplitudeSamples` field in `MsgFileInfo` is populated during recording but not rendered in v1. When waveform support is added:
- UI: replace progress bar with waveform bars derived from `amplitudeSamples`
- No data model migration needed — the field is already present
- No re-recording needed — amplitude data is stored with every voice message from day one
