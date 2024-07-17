// ignore_for_file: avoid_print

import 'dart:async';

void main() async {
  try {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  } on TimeoutException {
    print('WriteEventStatus Timeout after 1 seconds');
  }
  print('done');
}
