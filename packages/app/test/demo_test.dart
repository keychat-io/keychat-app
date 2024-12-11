import 'package:test/test.dart';

void main() {
  // Add your test cases here
  test('Example test', () {
    try {
      throw Exception('RelayDisconnected');
    } catch (e) {
      if (e.toString().contains('RelayDisconnected')) {
        print('RelayDisconnected, Please check your relay server');
      } else {
        print('Error: $e');
      }
    }
    expect(2 + 2, equals(4));
  });
}
