import 'package:flutter/foundation.dart' show debugPrint;
import 'package:test/test.dart';

void main() {
  // Add your test cases here
  test('Example test', () {
    try {
      throw Exception('RelayDisconnected');
    } catch (e) {
      if (e.toString().contains('RelayDisconnected')) {
        debugPrint('RelayDisconnected, Please check your relay server');
      } else {
        debugPrint('Error: $e');
      }
    }
    expect(2 + 2, equals(4));
  });
}
