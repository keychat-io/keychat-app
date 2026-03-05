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
