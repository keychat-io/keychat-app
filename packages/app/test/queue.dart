// The program calls the processIt function at various times.
// If new calls occur within a 100ms delay window,
// the call arguments are temporarily stored in a queue.
// However, when 100ms have passed and no new calls have arrived,
// the data in the queue is processed.
import 'dart:math';

import 'package:easy_debounce/easy_debounce.dart';

List<int> _queue = [];

void _processQueue() {
  for (var i in _queue) {
    print('process- ${DateTime.now()} : $i');
  }
  _queue.clear();
}

void proccessIt(int i) {
  _queue.add(i);
  EasyDebounce.debounce(
    'processQueue',
    const Duration(milliseconds: 1000),
    _processQueue,
  );
}

void main() async {
  for (var i = 0; i < 5; i++) {
    print('call - ${DateTime.now()} : $i');
    await Future.delayed(Duration(milliseconds: Random().nextInt(1000)));
    proccessIt(i);
  }
}
