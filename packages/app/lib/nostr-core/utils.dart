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

class EventKinds {
  static const int setMetadata = 0;
  static const int textNote = 1;
  static const int recommendServer = 2;
  static const int contactList = 3;
  static const int encryptedDirectMessage = 4;
  static const int delete = 5;
  static const int reaction = 7;
  static const int nip42 = 22242;
  // Channels
  // CHANNEL_CREATION = 40;
  // CHANNEL_METADATA = 41;
  // CHANNEL_MESSAGE = 42;
  // CHANNEL_HIDE_MESSAGE = 43;
  // CHANNEL_MUTE_USER = 44;
  // CHANNEL_RESERVED_FIRST = 45;
  // CHANNEL_RESERVED_LAST = 49;
  // Relay-only
  // RELAY_INVITE = 50;
  // INVOICE_UPDATE = 402;
  // // Replaceable events
  // REPLACEABLE_FIRST = 10000;
  // REPLACEABLE_LAST = 19999;
  // // Ephemeral events
  // EPHEMERAL_FIRST = 20000;
  // EPHEMERAL_LAST = 29999;
  // // Parameterized replaceable events
  // PARAMETERIZED_REPLACEABLE_FIRST = 30000;
  // PARAMETERIZED_REPLACEABLE_LAST = 39999;
  // USER_APPLICATION_FIRST = 40000;
  // USER_APPLICATION_LAST = Number.MAX_SAFE_INTEGER;
}
