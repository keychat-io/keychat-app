import 'dart:async';
import 'dart:convert' show base64Encode;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecordService {
  VoiceRecordService._();
  static VoiceRecordService? _instance;
  static VoiceRecordService get instance => _instance ??= VoiceRecordService._();

  AudioRecorder? _recorder;
  DateTime? _startTime;
  String? _currentPath;
  
  // Amplitude samples for waveform generation
  final List<double> _amplitudeSamples = [];
  Timer? _amplitudeTimer;

  bool get isRecording => _recorder != null && _currentPath != null;
  
  /// Start recording voice message in Opus/OGG format
  Future<void> startRecording() async {
    _recorder = AudioRecorder();
    
    if (!await _recorder!.hasPermission()) {
      throw Exception('Microphone permission denied');
    }
    
    final dir = await getTemporaryDirectory();
    _currentPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.ogg';
    
    _amplitudeSamples.clear();
    _startTime = DateTime.now();
    
    await _recorder!.start(
      const RecordConfig(
        encoder: AudioEncoder.opus,
        bitRate: 24000,     // 24kbps — good quality for voice
        sampleRate: 48000,  // 48kHz
        numChannels: 1,     // mono
      ),
      path: _currentPath!,
    );
    
    // Sample amplitude every 100ms for waveform
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      try {
        final amp = await _recorder?.getAmplitude();
        if (amp != null) {
          // amp.current is in dBFS (negative), normalize to 0.0-1.0
          final normalized = (amp.current + 50) / 50; // -50dB to 0dB range
          _amplitudeSamples.add(normalized.clamp(0.0, 1.0));
        }
      } catch (_) {}
    });
  }
  
  /// Stop recording and return result
  Future<VoiceRecordResult?> stopRecording() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    
    if (_recorder == null || _currentPath == null) return null;
    
    final path = await _recorder!.stop();
    final duration = _startTime != null 
        ? DateTime.now().difference(_startTime!).inSeconds 
        : 0;
    
    await _recorder!.dispose();
    _recorder = null;
    
    if (path == null || !File(path).existsSync()) return null;
    
    final waveform = _encodeWaveform(_amplitudeSamples);
    _amplitudeSamples.clear();
    _startTime = null;
    
    final result = VoiceRecordResult(
      filePath: path,
      duration: duration,
      waveform: waveform,
      amplitudeSamples: List.from(_amplitudeSamples),
    );
    _currentPath = null;
    return result;
  }
  
  /// Cancel recording and delete file
  Future<void> cancelRecording() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    
    if (_recorder != null) {
      await _recorder!.stop();
      await _recorder!.dispose();
      _recorder = null;
    }
    
    if (_currentPath != null) {
      final file = File(_currentPath!);
      if (file.existsSync()) file.deleteSync();
      _currentPath = null;
    }
    
    _amplitudeSamples.clear();
    _startTime = null;
  }
  
  /// Get current amplitude (0.0-1.0) for live waveform display
  Future<double> getCurrentAmplitude() async {
    if (_recorder == null) return 0.0;
    try {
      final amp = await _recorder!.getAmplitude();
      return ((amp.current + 50) / 50).clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }
  
  /// Encode amplitude samples into 5-bit packed waveform (Telegram-compatible)
  /// Each sample is 0-31 (5 bits), packed into bytes
  String _encodeWaveform(List<double> samples) {
    // Resample to ~100 points for consistent waveform length
    final targetLength = 100;
    final resampled = <double>[];
    
    if (samples.isEmpty) {
      return '';
    }
    
    for (var i = 0; i < targetLength; i++) {
      final idx = (i * samples.length / targetLength).floor();
      resampled.add(samples[idx.clamp(0, samples.length - 1)]);
    }
    
    // Pack 5-bit values into bytes
    final bits = <int>[];
    for (final sample in resampled) {
      bits.add((sample * 31).round().clamp(0, 31));
    }
    
    // 5 bits per sample, pack into bytes (8 bits)
    final byteCount = (bits.length * 5 + 7) ~/ 8;
    final bytes = Uint8List(byteCount);
    var bitPos = 0;
    
    for (final value in bits) {
      for (var bit = 0; bit < 5; bit++) {
        if (value & (1 << bit) != 0) {
          bytes[bitPos ~/ 8] |= (1 << (bitPos % 8));
        }
        bitPos++;
      }
    }
    
    return base64Encode(bytes);
  }
}

class VoiceRecordResult {
  VoiceRecordResult({
    required this.filePath,
    required this.duration,
    required this.waveform,
    this.amplitudeSamples = const [],
  });
  
  final String filePath;
  final int duration;       // seconds
  final String waveform;    // base64-encoded 5-bit packed
  final List<double> amplitudeSamples;
}
