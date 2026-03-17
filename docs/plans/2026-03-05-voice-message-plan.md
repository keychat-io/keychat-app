# Voice Message Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add press-and-hold voice message recording and playback to Keychat on iOS, Android, and macOS.

**Architecture:** A new `AudioMessageService` singleton handles recording (via `record` package) and playback (via `just_audio`). Voice messages reuse the existing `FileService` for encrypted upload and `sendMessage` for delivery. A new `audio` enum value in `MessageMediaType` triggers a new `VoiceMessageBubble` widget in the message list.

**Tech Stack:** `record ^5.2.0` (recording + amplitude), `just_audio ^0.9.42` (playback), existing `FileService` (encrypt + upload), existing `permission_handler` (mic permission)

---

## Task 1: Add dependencies and platform permissions

**Files:**
- Modify: `packages/app/pubspec.yaml` (around line 56–57, near `video_player`)
- Modify: `packages/app/ios/Runner/Info.plist`
- Modify: `packages/app/android/app/src/main/AndroidManifest.xml`
- Modify: `packages/app/macos/Runner/DebugProfile.entitlements`
- Modify: `packages/app/macos/Runner/Release.entitlements`

**Step 1: Add packages to pubspec.yaml**

In `pubspec.yaml`, after the `video_compress: ^3.1.4` line, add:
```yaml
  record: ^5.2.0          # audio recording
  just_audio: ^0.9.42     # audio playback
```

**Step 2: Run pub get**

```bash
cd packages/app && flutter pub get
```
Expected: No errors. Both packages resolved.

**Step 3: Add iOS microphone permission**

In `packages/app/ios/Runner/Info.plist`, add before the closing `</dict>`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Keychat needs microphone access to record voice messages.</string>
```

**Step 4: Add Android microphone permission**

In `packages/app/android/app/src/main/AndroidManifest.xml`, add before the `<application>` tag:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**Step 5: Add macOS microphone entitlement**

In both `packages/app/macos/Runner/DebugProfile.entitlements` and `packages/app/macos/Runner/Release.entitlements`, add after the `com.apple.security.device.camera` entry:
```xml
	<key>com.apple.security.device.audio-input</key>
	<true/>
```

**Step 6: Commit**

```bash
git add packages/app/pubspec.yaml packages/app/pubspec.lock \
  packages/app/ios/Runner/Info.plist \
  packages/app/android/app/src/main/AndroidManifest.xml \
  packages/app/macos/Runner/DebugProfile.entitlements \
  packages/app/macos/Runner/Release.entitlements
git commit -m "feat: add record and just_audio deps with platform mic permissions"
```

---

## Task 2: Extend the data model

**Files:**
- Modify: `packages/app/lib/models/message.dart` (line 43, after `messageReaction`)
- Modify: `packages/app/lib/models/embedded/msg_file_info.dart` (after line 38, after `sourceName`)

**Step 1: Write a failing test for MsgFileInfo serialization**

Create `packages/app/test/models/msg_file_info_audio_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/embedded/msg_file_info.dart';

void main() {
  group('MsgFileInfo audio fields', () {
    test('serializes audioDuration and amplitudeSamples', () {
      final mfi = MsgFileInfo()
        ..audioDuration = 12
        ..amplitudeSamples = [0.1, 0.5, 0.8];

      final json = mfi.toJson();
      expect(json['audioDuration'], 12);
      expect(json['amplitudeSamples'], [0.1, 0.5, 0.8]);

      final restored = MsgFileInfo.fromJson(json);
      expect(restored.audioDuration, 12);
      expect(restored.amplitudeSamples, [0.1, 0.5, 0.8]);
    });

    test('handles null audio fields gracefully', () {
      final mfi = MsgFileInfo();
      final json = mfi.toJson();
      expect(json.containsKey('audioDuration'), false);
      expect(json.containsKey('amplitudeSamples'), false);
    });
  });
}
```

**Step 2: Run test — verify it fails**

```bash
cd packages/app && flutter test test/models/msg_file_info_audio_test.dart
```
Expected: FAIL — `audioDuration` and `amplitudeSamples` don't exist yet.

**Step 3: Add `audio` to MessageMediaType**

In `packages/app/lib/models/message.dart`, add after `messageReaction` (line 43):
```dart
  messageReaction, // reaction to a message
  audio, // voice message
```

**Step 4: Add audio fields to MsgFileInfo**

In `packages/app/lib/models/embedded/msg_file_info.dart`, add after the `sourceName` field (line 38):
```dart
  String? sourceName;

  // Audio voice message metadata
  @JsonKey(includeIfNull: false)
  int? audioDuration; // duration in seconds

  @JsonKey(includeIfNull: false)
  List<double>? amplitudeSamples; // amplitude per 100ms, for future waveform
```

**Step 5: Regenerate code**

```bash
cd packages/app && dart run build_runner build --delete-conflicting-outputs
```
Expected: `msg_file_info.g.dart` and `message.g.dart` regenerated, no errors.

**Step 6: Run test — verify it passes**

```bash
cd packages/app && flutter test test/models/msg_file_info_audio_test.dart
```
Expected: PASS — both test cases green.

**Step 7: Commit**

```bash
git add packages/app/lib/models/message.dart \
  packages/app/lib/models/embedded/msg_file_info.dart \
  packages/app/lib/models/embedded/msg_file_info.g.dart \
  packages/app/lib/models/message.g.dart \
  packages/app/test/models/msg_file_info_audio_test.dart
git commit -m "feat: add audio MessageMediaType and audio fields to MsgFileInfo"
```

---

## Task 3: Create AudioMessageService

**Files:**
- Create: `packages/app/lib/service/audio_message.service.dart`

**Context:** This singleton manages recording and playback. Recording uses the `record` package. Playback uses `just_audio`. Only one audio message may play at a time — `currentPlayingMsgId` tracks this globally.

**Step 1: Create the service file**

Create `packages/app/lib/service/audio_message.service.dart`:
```dart
import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:keychat/models/embedded/msg_file_info.dart';
import 'package:keychat/models/message.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/utils.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

final logger = Logger();

class AudioMessageService {
  AudioMessageService._();
  static AudioMessageService? _instance;
  static AudioMessageService get instance =>
      _instance ??= AudioMessageService._();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // Reactive state for UI
  final RxBool isRecording = false.obs;
  final RxInt recordingSeconds = 0.obs;
  final RxString currentPlayingMsgId = ''.obs;
  final RxBool isPlaying = false.obs;
  final Rx<Duration> playbackPosition = Duration.zero.obs;
  final Rx<Duration> playbackDuration = Duration.zero.obs;

  Timer? _recordingTimer;
  String? _tempAudioPath;
  List<double> _amplitudeSamples = [];
  static const int maxDurationSeconds = 60;

  /// Requests microphone permission. Returns true if granted.
  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Starts audio recording. Returns false if permission denied.
  Future<bool> startRecording() async {
    final granted = await requestMicPermission();
    if (!granted) return false;

    final dir = await getTemporaryDirectory();
    _tempAudioPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _amplitudeSamples = [];

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000),
      path: _tempAudioPath!,
    );

    isRecording.value = true;
    recordingSeconds.value = 0;

    // Tick every second, collect amplitude every 100ms
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final amp = await _recorder.getAmplitude();
      // Normalize dBFS (-160 to 0) to 0.0–1.0
      final normalized = ((amp.current + 160) / 160).clamp(0.0, 1.0);
      _amplitudeSamples.add(normalized);

      if (_amplitudeSamples.length % 10 == 0) {
        recordingSeconds.value = _amplitudeSamples.length ~/ 10;
      }

      if (recordingSeconds.value >= maxDurationSeconds) {
        await stopAndSend(null); // auto-send at limit
      }
    });

    return true;
  }

  /// Cancels recording without sending.
  Future<void> cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _recorder.stop();
    isRecording.value = false;
    recordingSeconds.value = 0;
    if (_tempAudioPath != null) {
      final file = File(_tempAudioPath!);
      if (file.existsSync()) await file.delete();
    }
    _tempAudioPath = null;
    _amplitudeSamples = [];
  }

  /// Stops recording and sends the message to [room]. Pass null for auto-send.
  Future<void> stopAndSend(Room? room) async {
    if (!isRecording.value) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final duration = recordingSeconds.value;
    if (duration < 1) {
      await cancelRecording();
      return;
    }

    final path = await _recorder.stop();
    isRecording.value = false;
    recordingSeconds.value = 0;

    if (path == null) return;

    final samples = List<double>.from(_amplitudeSamples);
    _amplitudeSamples = [];

    // Use the room from parameter or fall back to _pendingRoom
    final targetRoom = room ?? _pendingRoom;
    if (targetRoom == null) return;

    try {
      final xfile = XFileCompat(path);
      await FileService.instance.handleSendAudioFile(
        targetRoom,
        path,
        duration,
        samples,
      );
    } catch (e, s) {
      logger.e('AudioMessageService: stopAndSend failed', error: e, stackTrace: s);
    }
  }

  Room? _pendingRoom;

  /// Set the room before starting recording (used for auto-send at 60s limit).
  void setPendingRoom(Room room) => _pendingRoom = room;

  // ── Playback ──────────────────────────────────────────────────────────────

  /// Plays a voice message. Stops any currently playing message first.
  Future<void> play(Message message) async {
    final mfi = MsgFileInfo.fromJson(
      // ignore: avoid_dynamic_calls
      (message.realMessage != null)
          ? (Map<String, dynamic>.from(
              // ignore: avoid_dynamic_calls
              Map<String, dynamic>.from({}),
            ))
          : {},
    );
    // Decode the realMessage JSON to get MsgFileInfo
    if (message.realMessage == null) return;

    final mfiData = MsgFileInfo.fromJson(
      Map<String, dynamic>.from(
        // Using dart:convert via FileService pattern
        _decodeJson(message.realMessage!),
      ),
    );

    if (mfiData.localPath == null) return;
    final filePath = '${Utils.appFolder.path}${mfiData.localPath}';
    if (!File(filePath).existsSync()) return;

    // Stop current playback if different message
    if (currentPlayingMsgId.value != message.msgid) {
      await _player.stop();
    }

    currentPlayingMsgId.value = message.msgid;

    await _player.setFilePath(filePath);

    _player.durationStream.listen((d) {
      if (d != null) playbackDuration.value = d;
    });
    _player.positionStream.listen((p) => playbackPosition.value = p);
    _player.playerStateStream.listen((state) {
      isPlaying.value = state.playing;
      if (state.processingState == ProcessingState.completed) {
        currentPlayingMsgId.value = '';
        isPlaying.value = false;
        playbackPosition.value = Duration.zero;
      }
    });

    await _player.play();
  }

  /// Pauses playback.
  Future<void> pause() async {
    await _player.pause();
    isPlaying.value = false;
  }

  /// Stops all playback.
  Future<void> stop() async {
    await _player.stop();
    currentPlayingMsgId.value = '';
    isPlaying.value = false;
    playbackPosition.value = Duration.zero;
  }

  Map<String, dynamic> _decodeJson(String s) {
    // dart:convert is imported via file.service dependency chain
    // We call jsonDecode inline here
    try {
      return Map<String, dynamic>.from(
        // ignore: avoid_dynamic_calls
        (jsonDecodeHelper(s) as Map),
      );
    } catch (_) {
      return {};
    }
  }

  void dispose() {
    _recordingTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
  }
}

// Helper to avoid importing dart:convert at top (already available via other imports in practice)
dynamic jsonDecodeHelper(String source) {
  // This will be resolved by dart:convert in the actual build
  // Import dart:convert at the top of the file
  throw UnimplementedError('Import dart:convert');
}
```

> **Note:** The above is a skeleton. The actual implementation in Step 2 will be the final clean version.

**Step 2: Write the final clean service (replace the file above)**

```dart
import 'dart:async';
import 'dart:convert' show jsonDecode;
import 'dart:io' show File;

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:keychat/models/embedded/msg_file_info.dart';
import 'package:keychat/models/message.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/utils.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

final _log = Logger();

class AudioMessageService {
  AudioMessageService._();
  static AudioMessageService? _instance;
  static AudioMessageService get instance =>
      _instance ??= AudioMessageService._();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  final RxBool isRecording = false.obs;
  final RxInt recordingSeconds = 0.obs;
  final RxString currentPlayingMsgId = ''.obs;
  final RxBool isPlaying = false.obs;
  final Rx<Duration> playbackPosition = Duration.zero.obs;
  final Rx<Duration> playbackDuration = Duration.zero.obs;

  Timer? _recordingTimer;
  String? _tempAudioPath;
  List<double> _amplitudeSamples = [];
  Room? _pendingRoom;
  static const int _maxSeconds = 60;

  /// Returns true if microphone permission is granted.
  Future<bool> requestMicPermission() async =>
      (await Permission.microphone.request()).isGranted;

  /// Begins recording. Returns false if permission denied.
  Future<bool> startRecording(Room room) async {
    if (!await requestMicPermission()) return false;
    _pendingRoom = room;

    final dir = await getTemporaryDirectory();
    _tempAudioPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _amplitudeSamples = [];

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000),
      path: _tempAudioPath!,
    );

    isRecording.value = true;
    recordingSeconds.value = 0;

    _recordingTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final amp = await _recorder.getAmplitude();
      final normalized = ((amp.current + 160) / 160).clamp(0.0, 1.0);
      _amplitudeSamples.add(normalized);

      final secs = _amplitudeSamples.length ~/ 10;
      recordingSeconds.value = secs;
      if (secs >= _maxSeconds) await stopAndSend();
    });

    return true;
  }

  /// Cancels in-progress recording without sending.
  Future<void> cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _recorder.stop();
    isRecording.value = false;
    recordingSeconds.value = 0;
    if (_tempAudioPath != null) {
      final f = File(_tempAudioPath!);
      if (f.existsSync()) await f.delete();
    }
    _tempAudioPath = null;
    _amplitudeSamples = [];
  }

  /// Stops recording and sends to [_pendingRoom]. Discards if < 1 second.
  Future<void> stopAndSend() async {
    if (!isRecording.value) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final duration = recordingSeconds.value;
    final path = await _recorder.stop();
    isRecording.value = false;
    recordingSeconds.value = 0;

    if (duration < 1 || path == null || _pendingRoom == null) {
      if (path != null) {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      }
      return;
    }

    final samples = List<double>.from(_amplitudeSamples);
    _amplitudeSamples = [];
    final room = _pendingRoom!;

    try {
      await FileService.instance.handleSendAudioFile(
        room,
        path,
        duration,
        samples,
      );
    } catch (e, s) {
      _log.e('stopAndSend failed', error: e, stackTrace: s);
    }
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  /// Plays the voice message. Stops any other playing message first.
  Future<void> play(Message message) async {
    if (message.realMessage == null) return;

    MsgFileInfo mfi;
    try {
      mfi = MsgFileInfo.fromJson(
        jsonDecode(message.realMessage!) as Map<String, dynamic>,
      );
    } catch (_) {
      return;
    }

    if (mfi.localPath == null) return;
    final filePath = '${Utils.appFolder.path}${mfi.localPath}';
    if (!File(filePath).existsSync()) return;

    if (currentPlayingMsgId.value != message.msgid) {
      await _player.stop();
      playbackPosition.value = Duration.zero;
    }

    currentPlayingMsgId.value = message.msgid;

    _player.durationStream.listen(
      (d) { if (d != null) playbackDuration.value = d; },
    );
    _player.positionStream.listen((p) => playbackPosition.value = p);
    _player.playerStateStream.listen((state) {
      isPlaying.value = state.playing;
      if (state.processingState == ProcessingState.completed) {
        currentPlayingMsgId.value = '';
        isPlaying.value = false;
        playbackPosition.value = Duration.zero;
      }
    });

    await _player.setFilePath(filePath);
    await _player.play();
  }

  /// Pauses playback.
  Future<void> pause() async {
    await _player.pause();
    isPlaying.value = false;
  }

  /// Stops all playback (call when leaving chat screen).
  Future<void> stop() async {
    await _player.stop();
    currentPlayingMsgId.value = '';
    isPlaying.value = false;
    playbackPosition.value = Duration.zero;
  }

  void dispose() {
    _recordingTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
  }
}
```

**Step 3: Add `handleSendAudioFile` to FileService**

In `packages/app/lib/service/file.service.dart`, after `handleSendMediaFile` (around line 970), add:
```dart
  /// Encrypts, uploads, and sends a voice message.
  Future<Message?> handleSendAudioFile(
    Room room,
    String audioPath,
    int durationSeconds,
    List<double> amplitudeSamples,
  ) async {
    final xfile = XFile(audioPath);
    try {
      EasyLoading.showProgress(0.1, status: 'Encrypting and Uploading...');
      final mfi = await FileService.instance.encryptToSendFile(
        room,
        xfile,
        MessageMediaType.audio,
        onSendProgress: (count, total) =>
            FileService.instance.onSendProgress('Uploading...', count, total),
      );
      if (mfi == null || mfi.fileInfo == null) return null;

      // Embed audio metadata into MsgFileInfo before serializing
      mfi
        ..audioDuration = durationSeconds
        ..amplitudeSamples = amplitudeSamples;

      EasyLoading.showProgress(1, status: 'Uploading...');
      final smr = await RoomService.instance.sendMessage(
        room,
        mfi.getUriString(MessageMediaType.audio.name),
        realMessage: mfi.toString(),
        mediaType: MessageMediaType.audio,
      );
      Future.delayed(const Duration(milliseconds: 500)).then((_) {
        EasyLoading.dismiss();
      });

      // Clean up temp file
      final f = File(audioPath);
      if (f.existsSync()) await f.delete();

      return smr.message;
    } catch (e, s) {
      final msg = Utils.getErrorMessage(e);
      _log.e('handleSendAudioFile: $msg', error: e, stackTrace: s);
      EasyLoading.showError(msg);
      return null;
    }
  }
```

> **Note:** You will need to add `import 'package:keychat/service/room.service.dart';` at the top of `file.service.dart` if not already present — check existing imports first.

**Step 4: Verify the app analyzes cleanly**

```bash
cd packages/app && flutter analyze lib/service/audio_message.service.dart lib/service/file.service.dart
```
Expected: No errors.

**Step 5: Commit**

```bash
git add packages/app/lib/service/audio_message.service.dart \
  packages/app/lib/service/file.service.dart
git commit -m "feat: add AudioMessageService and handleSendAudioFile to FileService"
```

---

## Task 4: Create VoiceMessageBubble widget

**Files:**
- Create: `packages/app/lib/page/chat/widgets/voice_message_bubble.dart`

**Context:** This widget renders a received/sent voice message. It shows a play/pause button, a progress bar, and duration. It subscribes to `AudioMessageService` reactive state via `Obx`.

**Step 1: Create the widget file**

```dart
import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/models/embedded/msg_file_info.dart';
import 'package:keychat/models/message.dart';
import 'package:keychat/service/audio_message.service.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/utils.dart';
import 'dart:io' show File;

class VoiceMessageBubble extends StatelessWidget {
  const VoiceMessageBubble(this.message, this.errorCallback, {super.key});

  final Message message;
  final Widget Function({Widget? child, String? text}) errorCallback;

  @override
  Widget build(BuildContext context) {
    MsgFileInfo mfi;
    try {
      mfi = MsgFileInfo.fromJson(
        jsonDecode(message.realMessage!) as Map<String, dynamic>,
      );
    } catch (_) {
      return errorCallback(text: '[Voice message error]');
    }

    final svc = AudioMessageService.instance;
    final totalSecs = mfi.audioDuration ?? 0;
    final totalDuration = Duration(seconds: totalSecs);

    return Obx(() {
      final isThisPlaying = svc.currentPlayingMsgId.value == message.msgid;
      final position = isThisPlaying ? svc.playbackPosition.value : Duration.zero;
      final duration = isThisPlaying && svc.playbackDuration.value > Duration.zero
          ? svc.playbackDuration.value
          : totalDuration;
      final progress = duration.inMilliseconds > 0
          ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

      return SizedBox(
        width: 200,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _onTap(context, mfi),
              child: Icon(
                isThisPlaying && svc.isPlaying.value
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progress.toDouble(),
                    backgroundColor:
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(isThisPlaying ? position : duration),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _onTap(BuildContext context, MsgFileInfo mfi) async {
    final svc = AudioMessageService.instance;

    // If playing this message, pause
    if (svc.currentPlayingMsgId.value == message.msgid && svc.isPlaying.value) {
      await svc.pause();
      return;
    }

    // Check if file needs to be downloaded first
    if (mfi.localPath == null) {
      await FileService.instance.downloadAndDecryptByMessage(message);
      return;
    }
    final filePath = '${Utils.appFolder.path}${mfi.localPath}';
    if (!File(filePath).existsSync()) {
      await FileService.instance.downloadAndDecryptByMessage(message);
      return;
    }

    await svc.play(message);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
```

> **Note:** `downloadAndDecryptByMessage` may not exist yet — check `FileService` for the equivalent download method. If the method name differs, adjust accordingly (search for `downloadAndDecrypt` in `file.service.dart`).

**Step 2: Verify analysis**

```bash
cd packages/app && flutter analyze lib/page/chat/widgets/voice_message_bubble.dart
```
Expected: No errors (warnings about missing method are OK — we'll fix in next step if needed).

**Step 3: Commit**

```bash
git add packages/app/lib/page/chat/widgets/voice_message_bubble.dart
git commit -m "feat: add VoiceMessageBubble widget with play/pause and progress bar"
```

---

## Task 5: Register audio type in RoomUtil

**Files:**
- Modify: `packages/app/lib/page/chat/RoomUtil.dart` (around line 1199–1200, in `getTextViewWidget` switch)

**Context:** `RoomUtil.getTextViewWidget` is the main dispatch point for rendering different message types. We add `case MessageMediaType.audio:` to route to our new bubble.

**Step 1: Add the audio case to the switch**

In `packages/app/lib/page/chat/RoomUtil.dart`, inside `getTextViewWidget`, after the `case MessageMediaType.file:` line (around line 1200):
```dart
        case MessageMediaType.file:
          return FileMessageWidget(message, errorCallback);
        case MessageMediaType.audio:
          return VoiceMessageBubble(message, errorCallback);
```

**Step 2: Add the import**

At the top of `RoomUtil.dart`, add with the other widget imports:
```dart
import 'package:keychat/page/chat/widgets/voice_message_bubble.dart';
```

**Step 3: Also update message_widget.dart delete handler**

In `packages/app/lib/page/chat/message_widget.dart`, find the delete logic (around line 933):
```dart
if (message.mediaType == MessageMediaType.file ||
    message.mediaType == MessageMediaType.image ||
    message.mediaType == MessageMediaType.video) {
```
Change to:
```dart
if (message.mediaType == MessageMediaType.file ||
    message.mediaType == MessageMediaType.image ||
    message.mediaType == MessageMediaType.video ||
    message.mediaType == MessageMediaType.audio) {
```

Also find the file info display section (around line 1088):
```dart
if (message.mediaType == MessageMediaType.file ||
    message.mediaType == MessageMediaType.image ||
    message.mediaType == MessageMediaType.video)
```
Change to:
```dart
if (message.mediaType == MessageMediaType.file ||
    message.mediaType == MessageMediaType.image ||
    message.mediaType == MessageMediaType.video ||
    message.mediaType == MessageMediaType.audio)
```

Also find the forward handler check (around line 1692):
```dart
(message.mediaType == MessageMediaType.text ||
    message.mediaType == MessageMediaType.image ||
    message.mediaType == MessageMediaType.video ||
    message.mediaType == MessageMediaType.file))
```
Add `audio` to that list as well.

**Step 4: Verify analysis**

```bash
cd packages/app && flutter analyze lib/page/chat/RoomUtil.dart lib/page/chat/message_widget.dart
```
Expected: No errors.

**Step 5: Commit**

```bash
git add packages/app/lib/page/chat/RoomUtil.dart \
  packages/app/lib/page/chat/message_widget.dart
git commit -m "feat: route audio MessageMediaType to VoiceMessageBubble in RoomUtil"
```

---

## Task 6: Create VoiceRecordButton widget

**Files:**
- Create: `packages/app/lib/page/chat/widgets/voice_record_button.dart`

**Context:** This widget renders the mic button in the chat input bar. It handles press-and-hold gesture with left-slide cancellation. It shows a visual timer overlay when recording.

**Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/service/audio_message.service.dart';

class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({required this.room, super.key});

  final Room room;

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  final AudioMessageService _svc = AudioMessageService.instance;

  // Track horizontal drag for cancel gesture
  double _startDx = 0;
  bool _isCancelled = false;
  static const double _cancelThreshold = 100.0;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isRecording = _svc.isRecording.value;

      return GestureDetector(
        onLongPressStart: (details) async {
          _startDx = details.globalPosition.dx;
          _isCancelled = false;
          final started = await _svc.startRecording(widget.room);
          if (!started && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Microphone permission required'),
                action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
              ),
            );
          }
        },
        onLongPressMoveUpdate: (details) {
          final dx = _startDx - details.globalPosition.dx;
          if (dx > _cancelThreshold && !_isCancelled) {
            _isCancelled = true;
            _svc.cancelRecording();
          }
        },
        onLongPressEnd: (_) async {
          if (!_isCancelled && _svc.isRecording.value) {
            await _svc.stopAndSend();
          }
          _isCancelled = false;
        },
        onLongPressCancel: () {
          _svc.cancelRecording();
          _isCancelled = false;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(4),
          decoration: isRecording
              ? BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                )
              : null,
          child: Icon(
            isRecording ? Icons.mic : Icons.mic_none_outlined,
            size: 28,
            color: isRecording ? Colors.red : null,
          ),
        ),
      );
    });
  }
}

// Needed for permission denied SnackBar action — import from permission_handler
void openAppSettings() {
  // permission_handler's openAppSettings()
  // import 'package:permission_handler/permission_handler.dart' show openAppSettings;
}
```

> **Note:** Replace the `openAppSettings` stub with the actual import from `permission_handler`:
> ```dart
> import 'package:permission_handler/permission_handler.dart' show openAppSettings;
> ```
> Then remove the local `openAppSettings()` function stub.

**Step 2: Verify analysis**

```bash
cd packages/app && flutter analyze lib/page/chat/widgets/voice_record_button.dart
```
Expected: No errors.

**Step 3: Commit**

```bash
git add packages/app/lib/page/chat/widgets/voice_record_button.dart
git commit -m "feat: add VoiceRecordButton with long-press and slide-to-cancel gesture"
```

---

## Task 7: Create VoiceRecordIndicator widget

**Files:**
- Create: `packages/app/lib/page/chat/widgets/voice_record_indicator.dart`

**Context:** When recording is in progress, the chat input row shows this overlay instead of the text field — it displays the elapsed time and a "slide left to cancel" hint.

**Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/service/audio_message.service.dart';

class VoiceRecordIndicator extends StatelessWidget {
  const VoiceRecordIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = AudioMessageService.instance;
    return Obx(() {
      final secs = svc.recordingSeconds.value;
      final minutes = (secs ~/ 60).toString().padLeft(2, '0');
      final seconds = (secs % 60).toString().padLeft(2, '0');

      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.circle, color: Colors.red, size: 10),
            const SizedBox(width: 8),
            Text(
              '$minutes:$seconds',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
            const Spacer(),
            Text(
              '← Slide to cancel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      );
    });
  }
}
```

**Step 2: Commit**

```bash
git add packages/app/lib/page/chat/widgets/voice_record_indicator.dart
git commit -m "feat: add VoiceRecordIndicator widget showing timer and cancel hint"
```

---

## Task 8: Integrate mic button into chat input UI

**Files:**
- Modify: `packages/app/lib/page/chat/chat_page.dart` (around line 290–335, the input Row)
- Modify: `packages/app/lib/page/chat/chat_page.dart` (around line 336, before `Expanded(child: KeyboardListener(...)`)

**Context:** We add the `VoiceRecordButton` to the input row. When recording is active (`AudioMessageService.instance.isRecording`), we replace the `TextFormField` with `VoiceRecordIndicator`. We also stop playback when leaving the chat page.

**Step 1: Add imports to chat_page.dart**

At the top of `packages/app/lib/page/chat/chat_page.dart`, add:
```dart
import 'package:keychat/page/chat/widgets/voice_record_button.dart';
import 'package:keychat/page/chat/widgets/voice_record_indicator.dart';
import 'package:keychat/service/audio_message.service.dart';
```

**Step 2: Add mic button and recording indicator to the input row**

In `_inputEditSection()`, find the Row children starting at around line 290. After the GIF/emoji `IconButton` (around line 334), add the mic button. Also wrap the `Expanded(child: KeyboardListener(...))` in an `Obx` to swap between text field and recording indicator.

Find this block (around line 334–336):
```dart
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),
                Expanded(
                  child: KeyboardListener(
```

Replace with:
```dart
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),
                Obx(() {
                  final isRecording =
                      AudioMessageService.instance.isRecording.value;
                  if (isRecording) {
                    return const Expanded(child: VoiceRecordIndicator());
                  }
                  return Expanded(
                    child: KeyboardListener(
```

And find the closing of the `Expanded` (the `),` that closes `KeyboardListener` and `Expanded`), then add the closing for the `Obx`:
```dart
                    child: KeyboardListener(
                      // ... existing content unchanged ...
                    ),
                  );
                }),
                Obx(() {
                  final isRecording =
                      AudioMessageService.instance.isRecording.value;
                  return Visibility(
                    visible: !isRecording,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: VoiceRecordButton(room: controller.roomObs.value),
                  );
                }),
```

> **IMPORTANT:** The exact indentation and surrounding code matters. Read `chat_page.dart` lines 334–510 carefully and make the minimal changes needed. The goal is:
> - When NOT recording: show text field + mic button side by side
> - When recording: replace text field with `VoiceRecordIndicator`, hide mic button

**Step 3: Stop playback when leaving chat**

Find the `dispose` method in `ChatController` at `packages/app/lib/controller/chat.controller.dart`. Add:
```dart
@override
void onClose() {
  AudioMessageService.instance.stop();
  super.onClose();
}
```

Check if `onClose` already exists — if so, just add `AudioMessageService.instance.stop();` to the beginning.

**Step 4: Verify the full app analyzes cleanly**

```bash
cd packages/app && flutter analyze lib/
```
Expected: No errors. Warnings OK.

**Step 5: Commit**

```bash
git add packages/app/lib/page/chat/chat_page.dart \
  packages/app/lib/controller/chat.controller.dart
git commit -m "feat: integrate VoiceRecordButton and VoiceRecordIndicator into chat input UI"
```

---

## Task 9: Manual integration test

**Goal:** Verify the full flow on a real device/simulator.

**Step 1: Run on iOS simulator**

```bash
cd packages/app && flutter run -d <ios-simulator-id>
```

**Checklist:**
- [ ] Open a 1:1 chat
- [ ] Mic button appears to the right of the text field
- [ ] Long-press mic: timer starts, input area shows red timer + "Slide to cancel"
- [ ] Hold for 3 seconds, release: message appears as sent voice bubble
- [ ] Tap play on the sent bubble: audio plays, progress bar moves
- [ ] Tap pause: pauses
- [ ] Open different chat while audio plays: audio stops
- [ ] Slide left during recording: message is NOT sent
- [ ] Hold for 60 seconds: auto-sends

**Step 2: Run on Android emulator**

```bash
cd packages/app && flutter run -d <android-emulator-id>
```

Same checklist as iOS.

**Step 3: Run on macOS**

```bash
cd packages/app && flutter run -d macos
```

Same checklist (if no mic, mic button should be disabled or not crash).

**Step 4: Commit final result**

```bash
git add -A
git commit -m "feat: voice message recording and playback complete"
```

---

## Task 10: Run lint and clean up

```bash
cd packages/app && melos run lint:all
```

Fix any lint errors. Then:

```bash
git add -A
git commit -m "chore: fix lint issues in voice message implementation"
```

---

## Summary of Files Changed

| File | Change |
|------|--------|
| `packages/app/pubspec.yaml` | Add `record` + `just_audio` |
| `packages/app/ios/Runner/Info.plist` | Add mic permission string |
| `packages/app/android/app/src/main/AndroidManifest.xml` | Add RECORD_AUDIO permission |
| `packages/app/macos/Runner/DebugProfile.entitlements` | Add audio-input entitlement |
| `packages/app/macos/Runner/Release.entitlements` | Add audio-input entitlement |
| `packages/app/lib/models/message.dart` | Add `audio` enum value |
| `packages/app/lib/models/embedded/msg_file_info.dart` | Add `audioDuration`, `amplitudeSamples` |
| `packages/app/lib/service/audio_message.service.dart` | **New** — recording + playback service |
| `packages/app/lib/service/file.service.dart` | Add `handleSendAudioFile` method |
| `packages/app/lib/page/chat/RoomUtil.dart` | Add `audio` case in switch |
| `packages/app/lib/page/chat/message_widget.dart` | Include `audio` in delete/file-info checks |
| `packages/app/lib/page/chat/chat_page.dart` | Add mic button + recording indicator |
| `packages/app/lib/controller/chat.controller.dart` | Stop playback on `onClose` |
| `packages/app/lib/page/chat/widgets/voice_record_button.dart` | **New** — long-press button |
| `packages/app/lib/page/chat/widgets/voice_record_indicator.dart` | **New** — recording status bar |
| `packages/app/lib/page/chat/widgets/voice_message_bubble.dart` | **New** — playback bubble |
| `packages/app/test/models/msg_file_info_audio_test.dart` | **New** — serialization tests |
