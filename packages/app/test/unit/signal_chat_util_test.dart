import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/service/signal_chat_util.dart';

void main() {
  group('SignalChatUtil', () {
    group('getToSignMessage', () {
      test('produces correct format: Keychat-<nostrId>-<signalId>-<time>', () {
        final result = SignalChatUtil.getToSignMessage(
          nostrId: 'abc123',
          signalId: 'def456',
          time: 1700000000,
        );
        expect(result, equals('Keychat-abc123-def456-1700000000'));
      });

      test('handles empty strings', () {
        final result = SignalChatUtil.getToSignMessage(
          nostrId: '',
          signalId: '',
          time: 0,
        );
        expect(result, equals('Keychat---0'));
      });

      test('handles long hex keys', () {
        final nostrId = 'a' * 64;
        final signalId = 'b' * 66;
        final result = SignalChatUtil.getToSignMessage(
          nostrId: nostrId,
          signalId: signalId,
          time: 1700000000,
        );
        expect(result, startsWith('Keychat-'));
        expect(result, contains(nostrId));
        expect(result, contains(signalId));
        expect(result, endsWith('-1700000000'));
      });
    });

    group('getPrekeySigContent', () {
      test('sorts IDs and joins with comma', () {
        final result = SignalChatUtil.getPrekeySigContent(['c', 'a', 'b']);
        expect(result, equals('a,b,c'));
      });

      test('single ID returns it unchanged', () {
        final result = SignalChatUtil.getPrekeySigContent(['only']);
        expect(result, equals('only'));
      });

      test('empty list returns empty string', () {
        final result = SignalChatUtil.getPrekeySigContent([]);
        expect(result, equals(''));
      });

      test('already sorted list stays the same', () {
        final result =
            SignalChatUtil.getPrekeySigContent(['alpha', 'beta', 'gamma']);
        expect(result, equals('alpha,beta,gamma'));
      });
    });
  });
}
