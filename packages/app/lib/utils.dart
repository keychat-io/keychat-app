import 'dart:async' show TimeoutException;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File, FileMode, Platform;
import 'dart:math' show Random;

import 'package:app/controller/setting.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/room.dart';
import 'package:app/page/routes.dart';
import 'package:app/service/SignerService.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils/config.dart';
import 'package:app/utils/log_file.dart';
import 'package:auto_size_text_plus/auto_size_text_plus.dart';
import 'package:avatar_plus/avatar_plus.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:convert/convert.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/index.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'desktop/DesktopController.dart';

Logger logger = Logger(
    filter: kReleaseMode ? MyLogFilter() : null,
    output: MyOutput(),
    printer: PrettyPrinter(
        dateTimeFormat:
            kDebugMode ? DateTimeFormat.onlyTime : DateTimeFormat.dateAndTime,
        colors: false,
        methodCount: 5));

Logger loggerNoLine = Logger(printer: PrettyPrinter(methodCount: 0));

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

String formatTime(int time, [String format = 'yyyy-MM-dd HH:mm:ss']) {
  DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(time);
  final dateFormat = DateFormat(format);
  return dateFormat.format(dateTime);
}

String formatTimeToHHmm(int time) {
  int minutes = time ~/ 60;
  int seconds = time % 60;

  String minutesStr = minutes.toString().padLeft(2, '0');
  String secondsStr = seconds.toString().padLeft(2, '0');

  return '$minutesStr:$secondsStr';
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

getPublicKeyDisplay(String publicKey, [int size = 6]) {
  int length = publicKey.length;
  if (length < 4) return publicKey;
  if (publicKey.startsWith('npub') || publicKey.startsWith('nsec')) {
    return '${publicKey.substring(0, size)}...${publicKey.substring(length - size)}';
  }
  return '0x${publicKey.substring(0, size)}...${publicKey.substring(length - size)}';
}

int getRegistrationId(String pubkey) {
  final hash = fastHash(pubkey).toString();
  final hashInt = int.parse(hash, radix: 10);
  return hashInt & 0xffffffff;
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

bool isBase64(String str) {
  RegExp regExp = RegExp(r'^[A-Za-z0-9+/]*={0,3}$');
  return regExp.hasMatch(str);
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

DateTime timestampToDateTime(int timestamp) {
  return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
}

class ErrorMessages {
  static String signalDecryptError = 'protobuf encoding was invalid';
  static String relayIsEmptyException = '''Relay disconnected. Please retry.''';
  static String noFundsInfo = '''Insufficient balance to pay relay. 
Please check ecash balance and mint.''';
  static String noFunds = 'No Funds';
  static String signedPrekeyNotfound = 'signed_pre_key not found';
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

class Utils {
  static final RegExp domainRegExp = RegExp(
      r'^(([a-zA-Z]{1})|([a-zA-Z]{1}[a-zA-Z]{1})|([a-zA-Z]{1}[0-9]{1})|([0-9]{1}[a-zA-Z]{1})|([a-zA-Z]{1}[-]{1}[a-zA-Z]{1})|([a-zA-Z]{1}[-]{1}[0-9]{1})|([0-9]{1}[-]{1}[a-zA-Z]{1}))(([a-zA-Z]{1}|[0-9]{1}|[-]{1}){1,61})+[.][a-zA-Z]{2,4}$');

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

  static bottomSheedAndHideStatusBar(Widget widget) async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    await Get.bottomSheet(
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
        widget,
        isScrollControlled: true,
        enterBottomSheetDuration: Duration.zero,
        exitBottomSheetDuration: Duration.zero);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));
  }

  static String capitalizeFirstLetter(String input) {
    if (input.isEmpty || input[0].contains(RegExp(r'[^a-zA-Z]'))) return input;
    if (input.length == 1) return input.toUpperCase();
    return input[0].toUpperCase() + input.substring(1);
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

  static String formatTimeMsg(DateTime formatDt) {
    int milliNow = DateTime.now().millisecondsSinceEpoch;
    int year = DateTime.now().year;
    int day = DateTime.now().day;
    int millisecond = formatDt.millisecondsSinceEpoch;
    int yearIn = formatDt.year;
    int month = formatDt.month;
    int dayIn = formatDt.day;
    int week = formatDt.weekday;
    int hour = formatDt.hour;
    int minute = formatDt.minute;
    String monStr, dayStr, hourStr, mmStr;
    String yearStr = yearIn.toString().substring(2, 4);
    if (hour > 12) {
      hourStr = "${hour - 12}";
    } else {
      hourStr = "$hour";
    }

    if (minute < 10) {
      mmStr = "0$minute";
    } else {
      mmStr = "$minute";
    }
    monStr = "$month";
    dayStr = "$dayIn";
    // String h_m = DateUtil.formatDate(formatDt, format: DateFormats.h_m);
    if (day == dayIn && milliNow - millisecond <= 24 * 3600 * 1000) {
      if (hour >= 0 && hour < 12) {
        return "$hourStr:$mmStr AM";
      } else {
        return "$hourStr:$mmStr PM";
      }
    } else if (milliNow - millisecond <= 72 * 3600 * 1000) {
      String weekday = "";
      switch (week) {
        case 1:
          weekday = "Mon";
          break;
        case 2:
          weekday = "Tue";
          break;
        case 3:
          weekday = "Wed";
          break;
        case 4:
          weekday = "Thu";
          break;
        case 5:
          weekday = "Fri";
          break;
        case 6:
          weekday = "Sat";
          break;
        case 7:
          weekday = "Sun";
          break;
        default:
          break;
      }
      return weekday;
    } else {
      if (yearIn == year) {
        return "$monStr/$dayStr";
      } else {
        return "$monStr/$dayStr/$yearStr";
      }
    }
  }

  static String generateRandomString(int length) {
    final random = Random();
    const availableChars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz';
    final randomString = List.generate(length,
            (index) => availableChars[random.nextInt(availableChars.length)])
        .join();

    return randomString;
  }

  static Widget genQRImage(String content,
      {double size = 300,
      double embeddedImageSize = 0,
      double padding = 8.0,
      Color backgroundColor = Colors.white,
      ImageProvider<Object>? embeddedImage}) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: QrImageView(
          data: content,
          gapless: false,
          backgroundColor: backgroundColor,
          padding: EdgeInsets.all(padding),
          embeddedImage: embeddedImage,
          embeddedImageStyle: QrEmbeddedImageStyle(
              size: Size(embeddedImageSize, embeddedImageSize)),
          size: size,
        ));
  }

  static Future<Directory> getAppFolder() async {
    Directory? directory;

    switch (Platform.operatingSystem) {
      case 'macos':
        // macOS: ~/Library/Application Support/<appName>
        directory = await getApplicationSupportDirectory();
        break;
      case 'windows':
        // Windows: %APPDATA%\<appName>
        String appData = Platform.environment['APPDATA']!;
        directory = Directory(path.join(appData, KeychatGlobal.appPackageName));
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
        break;
      case 'linux':
        // Linux: ~/.config/<appName>
        String home = Platform.environment['HOME']!;
        directory =
            Directory(path.join(home, '.config', KeychatGlobal.appPackageName));
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
        break;
      default:
        // For iOS, Android and other platforms
        directory = await getApplicationDocumentsDirectory();
        break;
    }
    return directory;
  }

  static Widget getAssetImage(String imageUrl,
      {double size = 42, double radius = 100}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        image: DecorationImage(
          image: Image.asset(imageUrl).image,
          fit: BoxFit.cover,
          scale: 0.6,
          colorFilter: const ColorFilter.mode(
            Colors.transparent,
            BlendMode.colorBurn,
          ),
        ),
      ),
    );
  }

  static Widget getAvatarDot(Room room, {double width = 50}) {
    int newMessageCount = room.unReadCount;
    RoomType chatType = room.type;

    late Widget child;
    if (chatType == RoomType.group) {
      String account = room.getRoomName();
      List<Color> colors = _getGroupColor(room.groupType);
      child = getAvatorByName(account,
          room: room, width: width, borderRadius: 12, backgroudColors: colors);
    } else {
      child =
          Utils.getRandomAvatar(room.toMainPubkey, height: width, width: width);
    }
    if (room.unReadCount == 0) return child;

    // mute room
    if (room.isMute) {
      return badges.Badge(
        position: badges.BadgePosition.topEnd(top: -5, end: -5),
        badgeAnimation: const badges.BadgeAnimation.fade(toAnimate: false),
        child: child,
      );
    }
    return badges.Badge(
      badgeContent: Text(
        "$newMessageCount",
        style: const TextStyle(color: Colors.white),
      ),
      badgeAnimation: const badges.BadgeAnimation.fade(toAnimate: false),
      position: badges.BadgePosition.topEnd(top: -8, end: -5),
      child: child,
    );
  }

  static Widget getAvatorByName(String account,
      {double width = 45,
      double fontSize = 16,
      Room? room,
      double borderRadius = 100,
      int nameLength = 2,
      List<Color>? backgroudColors}) {
    return Container(
        width: width,
        height: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
              colors: backgroudColors ??
                  [const Color(0xff713CD0), const Color(0xff945BF3)]),
        ),
        child: Center(
            child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: AutoSizeText(_getDisplayName(account, nameLength),
              minFontSize: 10,
              stepGranularity: 2,
              maxFontSize: fontSize,
              maxLines: 2,
              overflow: TextOverflow.clip,
              style: TextStyle(
                  fontSize: fontSize, color: Colors.white, height: 1.1)),
        )));
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

  static String getFormatTimeForMessage(DateTime formatDt) {
    int milliNow = DateTime.now().millisecondsSinceEpoch;
    int year = DateTime.now().year;
    int day = DateTime.now().day;
    int millisecond = formatDt.millisecondsSinceEpoch;
    int yearIn = formatDt.year;
    int month = formatDt.month;
    int dayIn = formatDt.day;
    int week = formatDt.weekday;
    int hour = formatDt.hour;
    int minute = formatDt.minute;
    String monStr, dayStr, hourStr, mmStr;
    String yearStr = yearIn.toString().substring(2, 4);
    if (hour > 12) {
      hourStr = "${hour - 12}";
    } else {
      hourStr = "$hour";
    }

    if (minute < 10) {
      mmStr = "0$minute";
    } else {
      mmStr = "$minute";
    }
    monStr = "$month";
    dayStr = "$dayIn";
    if (day == dayIn && milliNow - millisecond <= 24 * 3600 * 1000) {
      if (hour >= 0 && hour < 12) {
        return "$hourStr:$mmStr AM";
      } else {
        return "$hourStr:$mmStr PM";
      }
    } else if (milliNow - millisecond <= 72 * 3600 * 1000) {
      String weekday = "";
      switch (week) {
        case 1:
          weekday = "Mon";
          break;
        case 2:
          weekday = "Tue";
          break;
        case 3:
          weekday = "Wed";
          break;
        case 4:
          weekday = "Thu";
          break;
        case 5:
          weekday = "Fri";
          break;
        case 6:
          weekday = "Sat";
          break;
        case 7:
          weekday = "Sun";
          break;
        default:
          break;
      }
      if (hour >= 0 && hour < 12) {
        return "$weekday $hourStr:$mmStr AM";
      } else {
        return "$weekday $hourStr:$mmStr PM";
      }
    } else {
      if (yearIn == year) {
        if (hour >= 0 && hour < 12) {
          return "$monStr/$dayStr $hourStr:$mmStr AM";
        } else {
          return "$monStr/$dayStr $hourStr:$mmStr PM";
        }
        // return "$monStr/$dayStr";
      } else {
        if (hour >= 0 && hour < 12) {
          return "$monStr/$dayStr/$yearStr $hourStr:$mmStr AM";
        } else {
          return "$monStr/$dayStr/$yearStr $hourStr:$mmStr PM";
        }
        // return "$monStr/$dayStr/$yearStr";
      }
    }
  }

  static T? getGetxController<T>({String? tag}) {
    try {
      T t = Get.find<T>(tag: tag);
      return t;
    } catch (e) {
      return null;
    }
  }

  static T getOrPutGetxController<T extends GetxController>(
      {String? tag, required T Function() create}) {
    try {
      T t = Get.find<T>(tag: tag);
      return t;
    } catch (e) {
      return Get.put(create(), tag: tag);
    }
  }

  static List<String> getIntersection(List<String> list1, List<String> list2) {
    final set = Set<String>.from(list1);

    return list2.where((element) => set.contains(element)).toList();
  }

  static Widget? getNetworkImage(String? imageUrl,
      {double size = 36, double radius = 100}) {
    if (imageUrl == null) return null;

    if (imageUrl.toString().endsWith('svg')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SvgPicture.network(
          imageUrl,
          width: size,
          height: size,
          placeholderBuilder: (BuildContext context) =>
              Icon(Icons.image, size: size),
        ),
      );
    }
    Widget child = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Icon(Icons.image, size: size));
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
            scale: 0.6,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.colorBurn,
            ),
          ),
        ),
      ),
      placeholder: (context, url) => child,
      errorWidget: (context, url, error) => child,
    );
  }

  static Widget getNeworkImageOrDefault(String? imageUrl,
      {double size = 36, double radius = 100}) {
    if (imageUrl == null) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Icon(Icons.image, size: size));
    }
    return getNetworkImage(imageUrl, size: size, radius: radius)!;
  }

  static Widget getRandomAvatar(String id,
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

  static Future<Identity?> handleAmberLogin() async {
    TextEditingController controller = TextEditingController();
    var focusNode = FocusNode();

    return Get.dialog<Identity>(
      CupertinoAlertDialog(
        title: const Text('Login with Amber App'),
        content: Form(
          child: Column(
            children: [
              TextFormField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Nickname', border: OutlineInputBorder()),
                onFieldSubmitted: (c) async {
                  var identity = await _submitAmberLogin(controller);
                  Get.back(result: identity);
                },
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              var identity = await _submitAmberLogin(controller);
              Get.back(result: identity);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  static String hexToString(String input) {
    return String.fromCharCodes(List.generate(
        input.length ~/ 2,
        (index) =>
            int.parse(input.substring(index * 2, index * 2 + 2), radix: 16)));
  }

  static Uint8List hexToUint8List(String input) {
    return Uint8List.fromList(List.generate(
        input.length ~/ 2,
        (index) =>
            int.parse(input.substring(index * 2, index * 2 + 2), radix: 16)));
  }

  static void hideKeyboard(BuildContext context) {
    FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  static Future initLoggger(Directory directory) async {
    logger = Logger(
        filter: kReleaseMode ? MyLogFilter() : null,
        printer: PrettyPrinter(
            dateTimeFormat: kDebugMode
                ? DateTimeFormat.onlyTime
                : DateTimeFormat.dateAndTime,
            colors: false,
            methodCount: kReleaseMode ? 1 : 5),
        output: kReleaseMode
            ? LogFileOutputs(await Utils.createLogFile(directory.path))
            : null);
  }

  static bool isDomain(String str) {
    return domainRegExp.hasMatch(str);
  }

  static String randomString(int i) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(i, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  static String regrexLetter(String account, [int length = 2]) {
    return account.length > length - 1 ? account.substring(0, length) : account;
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

  static String stringToHex(String input) {
    return input.codeUnits
        .map((unit) => unit.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static String unit8ListToHex(Uint8List input) {
    return input.map((unit) => unit.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<List<String>> waitRelayOnline(
      {List<String>? defaultRelays}) async {
    WebsocketService? ws = getGetxController<WebsocketService>();
    int initAttempts = 0;
    const maxInitAttempts = 5;

    while (ws == null && initAttempts < maxInitAttempts) {
      initAttempts++;
      logger.d(
          'Waiting for WebsocketService to initialize... ($initAttempts/$maxInitAttempts)');
      await Future.delayed(const Duration(milliseconds: 300));
      ws = getGetxController<WebsocketService>();
    }

    if (ws == null) {
      logger.e(
          'Failed to initialize WebsocketService after $maxInitAttempts attempts');
      return [];
    }
    List<String> onlineRelays = ws.getOnlineSocketString();
    List<String> activeRelays = defaultRelays ?? [];
    if (activeRelays.isEmpty) {
      activeRelays = ws.getActiveRelayString();
    }
    int connectAttemptTimes = 0;
    int connectMaxAttemptTimes = 5;

    while (getIntersection(onlineRelays, activeRelays).isEmpty &&
        connectAttemptTimes < connectMaxAttemptTimes) {
      var debug = {
        connectAttemptTimes: connectAttemptTimes,
        'onlineRelays': onlineRelays,
        'activeRelays': activeRelays,
      };
      logger.d('Waiting for relays to be available... $debug');
      await Future.delayed(const Duration(seconds: 1));
      connectAttemptTimes++;
      onlineRelays = ws.getOnlineSocketString();
    }
    return getIntersection(onlineRelays, activeRelays);
  }

  static String _getDisplayName(String account, int nameLength) {
    if (account.length <= nameLength) return account;
    if (account.contains(' ')) {
      return account.split(' ').first;
    }
    if (account.contains('-')) {
      return account.split('-').first;
    }
    if (account.contains('_')) {
      return account.split('_').first;
    }
    if (RegExp(r'^[a-zA-Z0-9]+$').hasMatch(account)) {
      return account.split(RegExp(r'(?=[A-Z])|\s+')).first;
    }
    return account.substring(0, nameLength);
  }

  static List<Color> _getGroupColor(GroupType groupType) {
    switch (groupType) {
      case GroupType.mls:
        return [const Color(0xffEC6E0E), const Color(0xffDF4D9E)];
      case GroupType.sendAll:
        return [const Color(0xff945BF3), const Color(0xff713CD0)];
      case GroupType.kdf:
        return [const Color(0xffCE9FFC), const Color(0xff7367F0)];
      case GroupType.shareKey:
        return [const Color(0xff823C70), const Color(0xffAF362D)];
    }
  }

  static Future<Identity?> _submitAmberLogin(
      TextEditingController controller) async {
    String name = controller.text.trim();

    if (name.isEmpty) {
      EasyLoading.showError("Username is required");
      return null;
    }
    String? pubkey = await SignerService.instance.getPublicKey();
    if (pubkey == null) {
      EasyLoading.showError("Amber Not Authorized");
      return null;
    }

    EasyLoading.show(status: 'Loading...');

    try {
      var res = await IdentityService.instance.createIdentityByAmberPubkey(
        name: name,
        pubkey: pubkey,
      );
      EasyLoading.dismiss();

      return res;
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError("Failed to create identity: $e");
    }
    return null;
  }

  static Future offAndToNamedRoom(Room room, [dynamic arguments]) async {
    if (GetPlatform.isMobile) {
      await Get.offAndToNamed('/room/${room.id}', arguments: arguments ?? room);
      return;
    }

    Get.back();
    Get.find<DesktopController>().selectedRoom.value = room;
    await Get.toNamed('/room/${room.id}',
        arguments: arguments ?? room, id: GetXNestKey.room);
  }

  static Future offAllNamedRoom([dynamic arguments]) async {
    if (GetPlatform.isMobile) {
      await Get.offAllNamed(Routes.root, arguments: arguments);
      return;
    }
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
    await Get.offAndToNamed(Routes.roomEmpty,
        arguments: arguments, id: GetXNestKey.room);
  }

  static Future toNamedRoom(Room room, [dynamic arguments]) async {
    if (GetPlatform.isMobile) {
      await Get.toNamed('/room/${room.id}', arguments: arguments ?? room);
      return;
    }
    // nothing changed
    if (room.id == Get.find<DesktopController>().selectedRoom.value.id) {
      return;
    }
    Get.find<DesktopController>().selectedRoom.value = room;
    await Get.offAllNamed('/room/${room.id}',
        arguments: arguments ?? room, id: GetXNestKey.room);
  }
}
