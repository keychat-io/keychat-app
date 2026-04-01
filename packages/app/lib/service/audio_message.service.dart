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

/// Singleton service managing voice message recording and playback.
///
/// Recording uses the `record` package with AAC-LC encoding.
/// Playback uses `just_audio`. Only one message may play at a time.
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
  Room? _pendingRoom;

  /// Maximum recording duration in seconds.
  static const int maxRecordingSeconds = 60;
  static const int _timerIntervalMs = 100;
  static const int _samplesPerSecond = 1000 ~/ _timerIntervalMs;
  static const int _audioBitRate = 32000;
  static const String _audioFileExtension = 'm4a';
  static const double _dBFSFloor = 160.0;

  /// Returns true if microphone permission is granted.
  Future<bool> requestMicPermission() async =>
      (await Permission.microphone.request()).isGranted;

  /// Begins recording. Returns false if permission denied.
  Future<bool> startRecording(Room room) async {
    if (!await requestMicPermission()) return false;
    _pendingRoom = room;

    final dir = await getTemporaryDirectory();
    _tempAudioPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$_audioFileExtension';
    _amplitudeSamples = [];

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: _audioBitRate),
      path: _tempAudioPath!,
    );

    isRecording.value = true;
    recordingSeconds.value = 0;

    _recordingTimer =
        Timer.periodic(const Duration(milliseconds: _timerIntervalMs), (_) async {
      final amp = await _recorder.getAmplitude();
      final normalized =
          ((amp.current + _dBFSFloor) / _dBFSFloor).clamp(0.0, 1.0);
      _amplitudeSamples.add(normalized);

      final secs = _amplitudeSamples.length ~/ _samplesPerSecond;
      recordingSeconds.value = secs;
      if (secs >= maxRecordingSeconds) await stopAndSend();
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
      (d) {
        if (d != null) playbackDuration.value = d;
      },
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

  /// Releases resources.
  void dispose() {
    _recordingTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
  }
}
