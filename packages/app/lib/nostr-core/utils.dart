import 'dart:math';

import 'package:convert/convert.dart';

String addEscapeChars(String str) {
  String temp = "";
  temp = str.replaceAll("\"", "\\\"");
  return temp.replaceAll("\n", "\\n");
}

String unEscapeChars(String str) {
  String temp = str.replaceAll("\"", "\\\"");
  temp = temp.replaceAll("\n", "\\n");
  return temp;
}

String generate64RandomHexChars() {
  final random = Random.secure();
  final randomBytes = List<int>.generate(32, (i) => random.nextInt(256));
  return hex.encode(randomBytes);
}
