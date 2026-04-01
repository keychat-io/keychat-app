import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/embedded/msg_file_info.dart' show FileStatus, MsgFileInfo;
import 'package:keychat/service/audio_message.service.dart'
    show AudioMessageService;

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

    test('round-trips through JSON string encoding', () {
      final mfi = MsgFileInfo()
        ..url = 'https://s3.example.com/voice.m4a'
        ..suffix = 'm4a'
        ..size = 32000
        ..key = 'enckey123'
        ..iv = 'iv456'
        ..hash = 'sha256hash'
        ..sourceName = 'voice_1234.m4a'
        ..audioDuration = 45
        ..amplitudeSamples = [0.0, 0.3, 0.7, 1.0, 0.5];

      // Simulate the realMessage path: toJson -> jsonEncode -> jsonDecode -> fromJson
      final jsonString = jsonEncode(mfi.toJson());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final restored = MsgFileInfo.fromJson(decoded);

      expect(restored.url, 'https://s3.example.com/voice.m4a');
      expect(restored.suffix, 'm4a');
      expect(restored.size, 32000);
      expect(restored.key, 'enckey123');
      expect(restored.iv, 'iv456');
      expect(restored.hash, 'sha256hash');
      expect(restored.sourceName, 'voice_1234.m4a');
      expect(restored.audioDuration, 45);
      expect(restored.amplitudeSamples, [0.0, 0.3, 0.7, 1.0, 0.5]);
    });

    test('handles zero duration', () {
      final mfi = MsgFileInfo()..audioDuration = 0;
      final json = mfi.toJson();
      expect(json['audioDuration'], 0);
      final restored = MsgFileInfo.fromJson(json);
      expect(restored.audioDuration, 0);
    });

    test('handles empty amplitudeSamples list', () {
      final mfi = MsgFileInfo()..amplitudeSamples = [];
      final json = mfi.toJson();
      expect(json['amplitudeSamples'], <double>[]);
      final restored = MsgFileInfo.fromJson(json);
      expect(restored.amplitudeSamples, <double>[]);
    });

    test('handles max duration', () {
      const maxSecs = AudioMessageService.maxRecordingSeconds;
      // 10 samples per second (100ms interval)
      final sampleCount = maxSecs * 10;
      final mfi = MsgFileInfo()
        ..audioDuration = maxSecs
        ..amplitudeSamples =
            List.generate(sampleCount, (i) => i / sampleCount);

      final json = mfi.toJson();
      expect(json['audioDuration'], maxSecs);
      expect((json['amplitudeSamples'] as List).length, sampleCount);

      final restored = MsgFileInfo.fromJson(json);
      expect(restored.audioDuration, maxSecs);
      expect(restored.amplitudeSamples!.length, sampleCount);
      expect(restored.amplitudeSamples!.first, closeTo(0.0, 0.001));
      expect(
        restored.amplitudeSamples!.last,
        closeTo((sampleCount - 1) / sampleCount, 0.001),
      );
    });

    test('preserves existing non-audio fields when audio fields added', () {
      // Ensure adding audio fields does not break existing file fields
      final mfi = MsgFileInfo()
        ..localPath = '/files/image.png'
        ..url = 'https://example.com/file'
        ..size = 1024
        ..suffix = 'png'
        ..sourceName = 'photo.png';

      final json = mfi.toJson();
      // No audio fields should be present
      expect(json.containsKey('audioDuration'), false);
      expect(json.containsKey('amplitudeSamples'), false);
      // Existing fields intact
      expect(json['localPath'], '/files/image.png');
      expect(json['size'], 1024);
    });

    test('fromJson with extra fields alongside audio fields', () {
      final json = <String, dynamic>{
        'status': FileStatus.init.name,
        'size': 0,
        'audioDuration': 10,
        'amplitudeSamples': [0.5],
        'url': 'https://example.com/voice.m4a',
      };
      final mfi = MsgFileInfo.fromJson(json);
      expect(mfi.audioDuration, 10);
      expect(mfi.amplitudeSamples, [0.5]);
      expect(mfi.url, 'https://example.com/voice.m4a');
    });
  });
}
