// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  String foo = dotenv.get('FOO');

  print(foo);

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
