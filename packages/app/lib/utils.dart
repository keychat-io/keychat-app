import 'dart:async' show TimeoutException;
import 'dart:convert' show JsonEncoder, jsonEncode, jsonDecode;
import 'dart:io' show Directory, File, FileMode, Platform;
import 'dart:math' show Random;

import 'package:app/controller/setting.controller.dart';
import 'package:app/global.dart';

import 'package:app/service/storage.dart';
import 'package:app/utils/config.dart';
import 'package:app/utils/log_file.dart';
import 'package:avatar_plus/avatar_plus.dart';
import 'package:convert/convert.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/index.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

Logger logger = Logger(
    filter: kReleaseMode ? MyLogFilter() : null,
    output: MyOutput(),
    printer: PrettyPrinter(
        dateTimeFormat:
            kDebugMode ? DateTimeFormat.onlyTime : DateTimeFormat.dateAndTime,
        colors: false,
        methodCount: 5));

Logger loggerNoLine = Logger(printer: PrettyPrinter(methodCount: 0));

/// current unix timestamp in seconds
int currentUnixTimestampSeconds() {
  return DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

Map deepCloneMap(Map original) {
  Map cloned = {};
  original.forEach((key, value) {
    if (value is Map) {
      cloned[key] = deepCloneMap(value);
    } else {
      cloned[key] = value;
    }
  });
  return cloned;
}

// https://isar.dev/recipes/string_ids.html
Id fastHash(String pubkey) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < pubkey.length) {
    final codeUnit = pubkey.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}

bool isBase64(String str) {
  RegExp regExp = RegExp(r'^[A-Za-z0-9+/]*={0,3}$');
  return regExp.hasMatch(str);
}

String formatTimeToHHmm(int time) {
  int minutes = time ~/ 60;
  int seconds = time % 60;

  String minutesStr = minutes.toString().padLeft(2, '0');
  String secondsStr = seconds.toString().padLeft(2, '0');

  return '$minutesStr:$secondsStr';
}

String formatTimeToYYYYMMDDhhmm(int time) {
  DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(time);
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  return dateFormat.format(dateTime);
}

String formatTime(int time) {
  DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(time);
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  return dateFormat.format(dateTime);
}

String generate64RandomHexChars([int size = 32]) {
  final random = Random.secure();
  final randomBytes = List<int>.generate(size, (i) => random.nextInt(256));
  return hex.encode(randomBytes);
}

String generateRandomAESKey() {
  final random = Random.secure();
  final randomBytes = List<int>.generate(32, (i) => random.nextInt(256));
  return hex.encode(randomBytes);
}

T? getGetxController<T>() {
  try {
    T t = Get.find<T>();
    return t;
  } catch (e) {
    return null;
  }
}

getPublicKeyDisplay(String publicKey, [int size = 6]) {
  int length = publicKey.length;
  if (length < 4) return publicKey;
  if (publicKey.startsWith('npub') || publicKey.startsWith('nsec')) {
    return '${publicKey.substring(0, size)}...${publicKey.substring(length - size)}';
  }
  return '0x${publicKey.substring(0, size)}...${publicKey.substring(length - size)}';
}

Widget getRandomAvatar(String id,
    {double height = 40, double width = 40, BoxFit fit = BoxFit.contain}) {
  var avatarsFolder = Get.find<SettingController>().avatarsFolder;
  final filePath = '$avatarsFolder/$id.svg';
  final file = File(filePath);
  if (file.existsSync()) {
    return SvgPicture.file(file, width: width, height: height);
  } else {
    String svgCode = AvatarPlusGen.instance.generate(id);
    file.writeAsStringSync(svgCode);
    return SvgPicture.string(
      svgCode,
      width: width,
      height: height,
    );
  }
}

int getRegistrationId(String pubkey) {
  final hash = fastHash(pubkey).toString();
  final hashInt = int.parse(hash, radix: 10);
  return hashInt & 0xffffffff;
}

String getStrTagsFromJson(dynamic json) {
  String str = "";

  int i = 0;
  for (dynamic tag in json) {
    if (i != 0) {
      str += ",";
    }

    str += "[";
    int j = 0;
    for (dynamic element in tag) {
      if (j != 0) {
        str += ",";
      }
      str += "\"${element.toString()}\"";
      j++;
    }
    str += "]";
    i++;
  }
  return str;
}

Future<ThemeMode> getThemeMode() async {
  String? res = await Storage.getString(StorageKeyString.themeMode);
  if (res == null) return ThemeMode.system;
  if (ThemeMode.dark.name == res) return ThemeMode.dark;
  if (ThemeMode.system.name == res) return ThemeMode.system;
  if (ThemeMode.light.name == res) return ThemeMode.light;
  return ThemeMode.system;
}

String getYearMonthDay() {
  DateTime now = DateTime.now();
  int year = now.year;
  int month = now.month;
  int day = now.day;
  return "$year-$month-$day";
}

bool isEmail(String input) {
  const pattern =
      r'^[\w-]+(\.[\w-]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*(\.[a-zA-Z]{2,})$';
  final regex = RegExp(pattern);
  return regex.hasMatch(input);
}

bool isGiphyFile(String url) {
  RegExp domainRegex = RegExp(r'^https?:\/\/.*\.giphy\.com\/.*$');
  RegExp imageExtensionRegex = RegExp(r'\.(gif|jpg|jpeg|png|bmp|webp)$');

  return domainRegex.hasMatch(url) && imageExtensionRegex.hasMatch(url);
}

String jsonify(Object data, [bool prettyPrint = false]) {
  if (prettyPrint) {
    try {
      var encoder = const JsonEncoder.withIndent('  ');
      var prettyprint = encoder.convert(data);
      return prettyprint;
    } catch (e) {
      rethrow;
    }
  }

  return jsonEncode(data);
}

List<List<T>> listToGroupList<T>(List<T> source, int groupSize) {
  List<List<T>> groups = [];

  for (int i = 0; i < source.length; i += groupSize) {
    int size = groupSize;
    if (source.length - i <= groupSize) {
      size = source.length - i;
    }
    List<T> subArray = source.sublist(i, i + size);
    groups.add(subArray);
  }

  return groups;
}

Future<Map<String, dynamic>> parseJson(String text) {
  return compute(_parseAndDecode, text);
}

Uint8List randomBytes32() {
  final rand = Random.secure();
  final bytes = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    bytes[i] = rand.nextInt(256);
  }

  return bytes;
}

setLogger(Logger lg) {
  logger = lg;
}

DateTime timestampToDateTime(int timestamp) {
  return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
}

Map<String, dynamic> _parseAndDecode(String response) {
  return jsonDecode(response) as Map<String, dynamic>;
}

class MyLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}

class MyOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      if (kDebugMode) {
        print(line);
      }
    }
  }
}

class ErrorMessages {
  static String signalDecryptError = 'protobuf encoding was invalid';
  static String relayIsEmptyException = '''Relay disconnected. Please retry.''';
  static String noFundsInfo = '''Insufficient balance to pay relay. 
Please check ecash balance and mint.''';
  static String noFunds = 'No Funds';
  static String signedPrekeyNotfound = 'signed_pre_key not found';
}

class Utils {
  static Future<void> asyncWithTimeout(Function excute, Duration timeout,
      [String? errorMessage]) async {
    try {
      await excute().timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(errorMessage ?? 'Execute_timeout');
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  static initLoggger(Directory directory) async {
    setLogger(Logger(
        filter: kReleaseMode ? MyLogFilter() : null,
        printer: PrettyPrinter(
            dateTimeFormat: kDebugMode
                ? DateTimeFormat.onlyTime
                : DateTimeFormat.dateAndTime,
            colors: false,
            methodCount: kReleaseMode ? 1 : 4),
        output: kReleaseMode
            ? LogFileOutputs(await Utils.createLogFile(directory.path))
            : null));
  }

  static Future<File> createLogFile(String dbFolder) async {
    Directory logDir = Directory('$dbFolder/logs');
    logDir.createSync(recursive: true);
    String time = getYearMonthDay();
    File file = File('${logDir.path}/err_logs_$time.txt');
    if (file.existsSync()) return file;
    String initString = '''Init File: $time \n
 env: ${Config.env} \n
 kReleaseMode: $kReleaseMode \n
 kDebugMode: $kDebugMode \n
 path: ${file.path} \n''';
    file.writeAsStringSync(initString, mode: FileMode.writeOnlyAppend);
    return file;
  }

  static Future<List> getWebRTCServers() async {
    String? config =
        await Storage.getString(StorageKeyString.defaultWebRTCServers);
    if (config != null) {
      try {
        return jsonDecode(config);
      } catch (e) {
        // logger.d(e, error: e);
      }
    }
    Storage.setString(StorageKeyString.defaultWebRTCServers,
        jsonEncode(KeychatGlobal.webrtcIceServers));
    return KeychatGlobal.webrtcIceServers;
  }

  static void hideKeyboard(BuildContext context) {
    FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  static void showInfoDialog(String content, [String? title]) {
    Get.dialog(CupertinoAlertDialog(
      title: Text(title ?? 'Info'),
      content: Text(content),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text('OK'),
          onPressed: () {
            Get.back();
          },
        ),
      ],
    ));
  }

  static void showTwoActionDialog(
      {required String content,
      required String btnText,
      required Function onPressed,
      String? title}) {
    Get.dialog(CupertinoAlertDialog(
      title: Text(title ?? 'Info'),
      content: Text(content),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text('Cancel'),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          child: Text(btnText),
          onPressed: () {
            onPressed();
          },
        ),
      ],
    ));
  }

  static Future<PermissionStatus> getStoragePermission() async {
    if (Platform.isIOS) {
      return await Permission.storage.isGranted
          ? PermissionStatus.granted
          : await Permission.storage.request();
    }
    if (Platform.isAndroid) {
      return await Permission.photos.isGranted
          ? PermissionStatus.granted
          : await Permission.photos.request();
    }
    return await Permission.storage.status;
  }

  static String getDaysText(int days) {
    if (days < 0) days = 0;
    if (days == 0) return 'Never';
    if (days == 1) {
      return '1 day';
    }
    return '$days days';
  }

  static getErrorMessage(Object e) {
    if (e is! AnyhowException) return e.toString();

    int index = e.message.indexOf('Stack backtrace:');
    if (index == -1) return e.message;
    return e.message.substring(0, index).trim();
  }

  static String randomString(int i) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(i, (index) => chars[random.nextInt(chars.length)])
        .join();
  }
}
