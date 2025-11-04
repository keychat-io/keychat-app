import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/utils.dart';

void main() {
  group('Utils', () {
    group('randomInt', () {
      test('returns an integer with correct number of digits', () {
        for (var length = 1; length <= 10; length++) {
          final result = Utils.randomInt(length);
          expect(result.toString().length, lessThanOrEqualTo(length));
        }
      });

      test('returns different values on multiple calls', () {
        final results = <int>{};
        for (var i = 0; i < 100; i++) {
          results.add(Utils.randomInt(6));
        }
        // With 100 calls, we expect to get multiple different values
        expect(results.length, greaterThan(1));
      });

      test('returns a number between expected bounds', () {
        const length = 3;
        final result = Utils.randomInt(length);
        expect(result, greaterThanOrEqualTo(0));
        expect(result, lessThan(1000)); // 10^length
      });
    });
  });
}
