import 'dart:math';

import 'package:convert/convert.dart';

/// Escapes special characters in [str] for JSON string embedding.
///
/// Replaces double-quotes with `\"` and newlines with `\n`.
String addEscapeChars(String str) {
  String temp = "";
  temp = str.replaceAll("\"", "\\\"");
  return temp.replaceAll("\n", "\\n");
}

// DEPRECATED: has identical logic to addEscapeChars and does not unescape - candidate for removal
String unEscapeChars(String str) {
  String temp = str.replaceAll("\"", "\\\"");
  temp = temp.replaceAll("\n", "\\n");
  return temp;
}

/// Generates a cryptographically secure 64-character random hex string (32 bytes).
///
/// Returns a lowercase hex-encoded string suitable for use as a subscription ID or event ID.
String generate64RandomHexChars() {
  final random = Random.secure();
  final randomBytes = List<int>.generate(32, (i) => random.nextInt(256));
  return hex.encode(randomBytes);
}
