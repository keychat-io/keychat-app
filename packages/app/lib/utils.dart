import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File, FileMode, Platform, exit;
import 'dart:math' show Random;

import 'package:app/desktop/DesktopController.dart';
import 'package:app/global.dart';
import 'package:app/models/contact.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/room.dart';
import 'package:app/page/browser/SelectIdentityForward.dart';
import 'package:app/page/dbSetup/db_setting.dart';
import 'package:app/page/routes.dart';
import 'package:app/service/SignerService.dart';
import 'package:app/service/contact.service.dart';
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
import 'package:isar_community/isar.dart';
import 'package:keychat_rust_ffi_plugin/index.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

Logger logger = Logger(
  filter: kReleaseMode ? MyLogFilter() : null,
  output: MyOutput(),
  printer: PrettyPrinter(
    dateTimeFormat: kDebugMode
        ? DateTimeFormat.onlyTime
        : DateTimeFormat.dateAndTime,
    colors: false,
    methodCount: 5,
  ),
);

Logger loggerNoLine = Logger(printer: PrettyPrinter(methodCount: 0));

String formatTime(int time, [String format = 'yyyy-MM-dd HH:mm:ss']) {
  // Check if time is in seconds (< 10000000000) or milliseconds
  final milliseconds = time < 10000000000 ? time * 1000 : time;
  final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final dateFormat = DateFormat(format);
  return dateFormat.format(dateTime);
}

String formatTimeToHHmm(int time) {
  if (time < 0) return '00:00'; // Handle negative time
  final minutes = time ~/ 60;
  final seconds = time % 60;

  final minutesStr = minutes.toString().padLeft(2, '0');
  final secondsStr = seconds.toString().padLeft(2, '0');

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

String getPublicKeyDisplay(String publicKey, [int size = 6]) {
  final length = publicKey.length;
  if (length < 4) return publicKey;
  if (size * 2 >= length) return publicKey; // Prevent index out of bounds
  if (publicKey.startsWith('npub') || publicKey.startsWith('nsec')) {
    return '${publicKey.substring(0, size)}...${publicKey.substring(length - size)}';
  }
  return '0x${publicKey.substring(0, size)}...${publicKey.substring(length - size)}';
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

int getRegistrationId(String pubkey) {
  final hash = fastHash(pubkey).toString();
  final hashInt = int.parse(hash, radix: 10);
  return hashInt & 0xffffffff;
}

Future<ThemeMode> getThemeMode() async {
  final res = Storage.getString(StorageKeyString.themeMode);
  if (res == null) return ThemeMode.system;
  if (ThemeMode.dark.name == res) return ThemeMode.dark;
  if (ThemeMode.system.name == res) return ThemeMode.system;
  if (ThemeMode.light.name == res) return ThemeMode.light;
  return ThemeMode.system;
}

String getYearMonthDay() {
  final now = DateTime.now();
  final year = now.year;
  final month = now.month;
  final day = now.day;
  return '$year-$month-$day';
}

bool isBase64(String str) {
  final regExp = RegExp(r'^[A-Za-z0-9+/]*={0,3}$');
  return regExp.hasMatch(str);
}

bool isEmail(String input) {
  const pattern =
      r'^[\w-]+(\.[\w-]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*(\.[a-zA-Z]{2,})$';
  final regex = RegExp(pattern);
  return regex.hasMatch(input);
}

bool isGiphyFile(String url) {
  final domainRegex = RegExp(r'^https?:\/\/.*\.giphy\.com\/.*$');
  final imageExtensionRegex = RegExp(r'\.(gif|jpg|jpeg|png|bmp|webp)$');

  return domainRegex.hasMatch(url) && imageExtensionRegex.hasMatch(url);
}

bool isPdfUrl(String url) {
  final regex = RegExp(r'\.pdf($|[\?#])', caseSensitive: false);
  return regex.hasMatch(url);
}

List<List<T>> listToGroupList<T>(List<T> source, int groupSize) {
  final groups = <List<T>>[];

  for (var i = 0; i < source.length; i += groupSize) {
    var size = groupSize;
    if (source.length - i <= groupSize) {
      size = source.length - i;
    }
    final subArray = source.sublist(i, i + size);
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
  static String noFundsInfo = '''
Insufficient balance to pay relay. 
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
    for (final line in event.lines) {
      if (kDebugMode) {
        print(line);
      }
    }
  }
}

class Utils {
  static bool isValidDomain(String domain) {
    final domainRegex = RegExp(
      r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$',
    );

    if (domain.length > 253) {
      return false;
    }

    if (domain.contains('..') ||
        domain.contains('--') ||
        domain.startsWith('-') ||
        domain.endsWith('-')) {
      return false;
    }

    return domainRegex.hasMatch(domain);
  }

  static Future<void> bottomSheedAndHideStatusBar(Widget widget) async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [],
    );
    await Get.bottomSheet<void>(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      widget,
      isScrollControlled: true,
      ignoreSafeArea: false,
      enterBottomSheetDuration: Duration.zero,
      exitBottomSheetDuration: Duration.zero,
    );
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  static String capitalizeFirstLetter(String input) {
    if (input.isEmpty || input[0].contains(RegExp('[^a-zA-Z]'))) return input;
    if (input.length == 1) return input.toUpperCase();
    return input[0].toUpperCase() + input.substring(1);
  }

  static Future<File> createLogFile(String dbFolder) async {
    final logDir = Directory('$dbFolder/logs')..createSync(recursive: true);
    final time = getYearMonthDay();
    final file = File('${logDir.path}/err_logs_$time.txt');
    if (file.existsSync()) return file;
    final initString =
        '''
Init File: $time \n
 env: ${Config.env} \n
 kReleaseMode: $kReleaseMode \n
 kDebugMode: $kDebugMode \n
 path: ${file.path} \n''';
    file.writeAsStringSync(initString, mode: FileMode.writeOnlyAppend);
    return file;
  }

  static String formatTimeMsg(DateTime formatDt) {
    final milliNow = DateTime.now().millisecondsSinceEpoch;
    final year = DateTime.now().year;
    final day = DateTime.now().day;
    final millisecond = formatDt.millisecondsSinceEpoch;
    final yearIn = formatDt.year;
    final month = formatDt.month;
    final dayIn = formatDt.day;
    final week = formatDt.weekday;
    final hour = formatDt.hour;
    final minute = formatDt.minute;
    String monStr;
    String dayStr;
    String hourStr;
    String mmStr;
    final yearStr = yearIn.toString().substring(2, 4);

    // Fix hour formatting logic
    if (hour == 0) {
      hourStr = '12'; // 12 AM
    } else if (hour > 12) {
      hourStr = '${hour - 12}';
    } else if (hour == 12) {
      hourStr = '12'; // 12 PM
    } else {
      hourStr = '$hour';
    }

    if (minute < 10) {
      mmStr = '0$minute';
    } else {
      mmStr = '$minute';
    }
    monStr = '$month';
    dayStr = '$dayIn';

    if (day == dayIn && milliNow - millisecond <= 24 * 3600 * 1000) {
      if (hour >= 0 && hour < 12) {
        return '$hourStr:$mmStr AM';
      } else {
        return '$hourStr:$mmStr PM';
      }
    } else if (milliNow - millisecond <= 72 * 3600 * 1000) {
      var weekday = '';
      switch (week) {
        case 1:
          weekday = 'Mon';
        case 2:
          weekday = 'Tue';
        case 3:
          weekday = 'Wed';
        case 4:
          weekday = 'Thu';
        case 5:
          weekday = 'Fri';
        case 6:
          weekday = 'Sat';
        case 7:
          weekday = 'Sun';
        default:
          weekday = 'Unknown'; // Add default case
      }
      return weekday;
    } else {
      if (yearIn == year) {
        return '$monStr/$dayStr';
      } else {
        return '$monStr/$dayStr/$yearStr';
      }
    }
  }

  static String generateRandomString(int length) {
    final random = Random();
    const availableChars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz';
    final randomString = List.generate(
      length,
      (index) => availableChars[random.nextInt(availableChars.length)],
    ).join();

    return randomString;
  }

  static Widget genQRImage(
    String content, {
    double size = 300,
    double embeddedImageSize = 0,
    double padding = 8.0,
    Color backgroundColor = Colors.white,
    ImageProvider<Object>? embeddedImage,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: QrImageView(
        data: content,
        gapless: false,
        backgroundColor: backgroundColor,
        padding: EdgeInsets.all(padding),
        embeddedImage: embeddedImage,
        embeddedImageStyle: QrEmbeddedImageStyle(
          size: Size(embeddedImageSize, embeddedImageSize),
        ),
        size: size,
      ),
    );
  }

  static Directory appFolder = Directory('/');
  static Future<Directory> getAppFolder() async {
    Directory? directory;

    switch (Platform.operatingSystem) {
      case 'macos':
        // macOS: ~/Library/Application Support/<appName>
        directory = await getApplicationSupportDirectory();
      case 'windows':
        // Windows: %APPDATA%\<appName>
        final appData = Platform.environment['APPDATA']!;
        directory = Directory(path.join(appData, KeychatGlobal.appPackageName));
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
      case 'linux':
        // Linux: ~/.config/<appName>
        final home = Platform.environment['HOME']!;
        directory = Directory(
          path.join(home, '.config', KeychatGlobal.appPackageName),
        );
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
      default:
        // For iOS, Android and other platforms
        directory = await getApplicationDocumentsDirectory();
    }
    initDirectory(directory);
    return directory;
  }

  static String avatarsFolder = '';
  static String browserCacheFolder = '';
  static String browserUserDataFolder = '';

  static void initDirectory(Directory directory) {
    appFolder = directory;
    avatarsFolder = '${directory.path}/avatars';
    browserCacheFolder = '${directory.path}/browserCache';

    // avatar folder
    avatarsFolder = '${Utils.appFolder.path}/avatars';
    browserCacheFolder = '${Utils.appFolder.path}/browserCache';
    final errorsFolder = '${Utils.appFolder.path}/errors';

    for (final folder in [avatarsFolder, browserCacheFolder, errorsFolder]) {
      final exist = Directory(folder).existsSync();
      if (!exist) {
        Directory(folder).createSync(recursive: true);
      }
    }
  }

  static Widget getAssetImage(
    String imageUrl, {
    double size = 48,
    double radius = 100,
  }) {
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

  static Widget getAvatarByImageFile(
    File image, {
    double size = 48,
    double radius = 100,
  }) {
    // Handle SVG files
    if (path.extension(image.path) == '.svg') {
      return SvgPicture.file(
        key: ObjectKey('avatar:${image.path}'),
        image,
        width: size,
        height: size,
      );
    }
    return Container(
      key: ObjectKey('avatar:${image.path}'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.white.withAlpha(100), // Add white background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        image: DecorationImage(
          image: Image.file(image).image,
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

  // Add avatar widget cache
  static final Map<String, Widget> _avatarWidgetCache = {};

  static Widget getAvatarByRoom(Room room, {double size = 48}) {
    final newMessageCount = room.unReadCount;
    final chatType = room.type;
    final cacheKey = 'avatar_${room.toMainPubkey}_$size';

    // Return cached widget if available
    if (_avatarWidgetCache.containsKey(cacheKey)) {
      final cachedWidget = _avatarWidgetCache[cacheKey]!;

      // For badges that need to be updated dynamically
      if (room.unReadCount == 0) {
        return cachedWidget;
      }

      // Only rebuild badge part if needed
      if (room.isMute) {
        return badges.Badge(
          position: badges.BadgePosition.topEnd(top: -5, end: -5),
          badgeAnimation: const badges.BadgeAnimation.fade(toAnimate: false),
          child: cachedWidget,
        );
      }

      return badges.Badge(
        badgeContent: Text(
          '$newMessageCount',
          style: const TextStyle(color: Colors.white),
        ),
        badgeAnimation: const badges.BadgeAnimation.fade(toAnimate: false),
        position: badges.BadgePosition.topEnd(end: -5),
        child: cachedWidget,
      );
    }

    // Create the base avatar widget
    late Widget child;
    if (chatType == RoomType.group) {
      final account = room.getRoomName();
      final colors = _getGroupColor(room.groupType);
      child = getAvatorByName(
        account,
        room: room,
        width: size,
        borderRadius: 12,
        backgroudColors: colors,
      );
    } else {
      child = Utils.getRandomAvatar(
        room.toMainPubkey,
        size: size,
        contact: room.contact,
      );
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
        '$newMessageCount',
        style: const TextStyle(color: Colors.white),
      ),
      badgeAnimation: const badges.BadgeAnimation.fade(toAnimate: false),
      position: badges.BadgePosition.topEnd(end: -5),
      child: child,
    );
  }

  // clear avatar cache by pubkey
  static void removeAvatarCacheByPubkey(String pubkey) {
    _avatarWidgetCache.keys
        .where((key) => key.contains(pubkey))
        .toList()
        .forEach(_avatarWidgetCache.remove);
  }

  static void clearAvatarCache() {
    _avatarWidgetCache.clear();
  }

  static Widget getAvatorByName(
    String account, {
    double width = 48,
    double fontSize = 16,
    Room? room,
    double borderRadius = 100,
    int nameLength = 2,
    List<Color>? backgroudColors,
  }) {
    return Container(
      width: width,
      height: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors:
              backgroudColors ??
              [const Color(0xff713CD0), const Color(0xff945BF3)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AutoSizeText(
            _getDisplayName(account, nameLength),
            minFontSize: 10,
            stepGranularity: 2,
            maxFontSize: fontSize,
            maxLines: 2,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  static String getDaysText(int days) {
    if (days < 0) days = 0;
    if (days == 0) return 'Never';
    if (days == 1) {
      return '1 day';
    }
    return '$days days';
  }

  static String getErrorMessage(Object e) {
    if (e is! AnyhowException) return e.toString();

    final index = e.message.indexOf('Stack backtrace:');
    var message = e.message;
    if (index != -1) {
      message = e.message.substring(0, index).trim();
    }
    final causedByIndex = message.indexOf('Caused by:');
    if (causedByIndex != -1) {
      return message.substring(0, causedByIndex).trim();
    }
    return message;
  }

  static String formatTimeForMessage(DateTime formatDt) {
    final milliNow = DateTime.now().millisecondsSinceEpoch;
    final year = DateTime.now().year;
    final day = DateTime.now().day;
    final millisecond = formatDt.millisecondsSinceEpoch;
    final yearIn = formatDt.year;
    final month = formatDt.month;
    final dayIn = formatDt.day;
    final week = formatDt.weekday;
    final hour = formatDt.hour;
    final minute = formatDt.minute;
    String monStr;
    String dayStr;
    String hourStr;
    String mmStr;
    final yearStr = yearIn.toString().substring(2, 4);

    // Fix hour formatting logic
    if (hour == 0) {
      hourStr = '12'; // 12 AM
    } else if (hour > 12) {
      hourStr = '${hour - 12}';
    } else if (hour == 12) {
      hourStr = '12'; // 12 PM
    } else {
      hourStr = '$hour';
    }

    if (minute < 10) {
      mmStr = '0$minute';
    } else {
      mmStr = '$minute';
    }
    monStr = '$month';
    dayStr = '$dayIn';

    if (day == dayIn && milliNow - millisecond <= 24 * 3600 * 1000) {
      if (hour >= 0 && hour < 12) {
        return '$hourStr:$mmStr AM';
      } else {
        return '$hourStr:$mmStr PM';
      }
    } else if (milliNow - millisecond <= 72 * 3600 * 1000) {
      var weekday = '';
      switch (week) {
        case 1:
          weekday = 'Mon';
        case 2:
          weekday = 'Tue';
        case 3:
          weekday = 'Wed';
        case 4:
          weekday = 'Thu';
        case 5:
          weekday = 'Fri';
        case 6:
          weekday = 'Sat';
        case 7:
          weekday = 'Sun';
        default:
          weekday = 'Unknown'; // Add default case
      }
      if (hour >= 0 && hour < 12) {
        return '$weekday $hourStr:$mmStr AM';
      } else {
        return '$weekday $hourStr:$mmStr PM';
      }
    } else {
      if (yearIn == year) {
        if (hour >= 0 && hour < 12) {
          return '$monStr/$dayStr $hourStr:$mmStr AM';
        } else {
          return '$monStr/$dayStr $hourStr:$mmStr PM';
        }
      } else {
        if (hour >= 0 && hour < 12) {
          return '$monStr/$dayStr/$yearStr $hourStr:$mmStr AM';
        } else {
          return '$monStr/$dayStr/$yearStr $hourStr:$mmStr PM';
        }
      }
    }
  }

  static T? getGetxController<T>({String? tag}) {
    try {
      final t = Get.find<T>(tag: tag);
      return t;
    } catch (e) {
      return null;
    }
  }

  static T getOrPutGetxController<T extends GetxController>({
    required T Function() create,
    String? tag,
  }) {
    try {
      final t = Get.find<T>(tag: tag);
      return t;
    } catch (e) {
      return Get.put(create(), tag: tag);
    }
  }

  static List<String> getIntersection(List<String> list1, List<String> list2) {
    final set = Set<String>.from(list1);

    return list2.where(set.contains).toList();
  }

  static Widget? getNetworkImage(
    String? imageUrl, {
    double size = 36,
    double radius = 100,
    Widget? placeholder,
  }) {
    if (imageUrl == null) return null;

    if (imageUrl.endsWith('svg')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SvgPicture.network(
          imageUrl,
          width: size,
          height: size,
          placeholderBuilder: (BuildContext context) =>
              placeholder ?? Icon(Icons.image, size: size),
        ),
      );
    }
    placeholder ??= ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Icon(CupertinoIcons.compass, size: size),
    );
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
      placeholder: (context, url) => placeholder!,
      errorWidget: (context, url, error) => placeholder!,
    );
  }

  static Widget getNeworkImageOrDefault(
    String? imageUrl, {
    double size = 36,
    double radius = 100,
  }) {
    if (imageUrl == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Icon(CupertinoIcons.photo, size: size),
      );
    }
    return getNetworkImage(imageUrl, size: size, radius: radius)!;
  }

  static Widget getRandomAvatar(
    String pubkey, {
    double size = 48,
    Contact? contact,
  }) {
    final cacheKey = 'avatar_${pubkey}_$size';
    if (_avatarWidgetCache.containsKey(cacheKey)) {
      return _avatarWidgetCache[cacheKey]!;
    }

    contact ??= ContactService.instance.getContactByPubkeySync(pubkey);

    // from contact
    if (contact != null) {
      final localFilePath =
          contact.avatarLocalPath ?? contact.avatarFromRelayLocalPath;

      if (localFilePath != null) {
        final file = File('${Utils.appFolder.path}$localFilePath');
        if (file.existsSync()) {
          final widget = getAvatarByImageFile(file, size: size);
          _avatarWidgetCache[cacheKey] = widget;
          return widget;
        }
      }
    }

    // use random avatar
    final widget = _generateRandomAvatar(pubkey, size: size);
    _avatarWidgetCache[cacheKey] = widget;
    return widget;
  }

  static SvgPicture _generateRandomAvatar(String id, {double size = 48}) {
    final filePath = '${Utils.avatarsFolder}/$id.svg';
    final file = File(filePath);

    // Use a consistent key for the SVG picture
    final objectKey = ValueKey('svgavatar:$id:$size');

    if (file.existsSync()) {
      return SvgPicture.file(
        file,
        width: size,
        height: size,
        key: objectKey,
      );
    } else {
      final svgCode = AvatarPlusGen.instance.generate(id);
      file.writeAsStringSync(svgCode);
      return SvgPicture.string(
        svgCode,
        width: size,
        height: size,
        key: objectKey,
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
    return Permission.storage.status;
  }

  static Future<List<dynamic>> getWebRTCServers() async {
    final config = Storage.getString(StorageKeyString.defaultWebRTCServers);
    if (config != null) {
      try {
        return jsonDecode(config) as List<dynamic>;
      } catch (e) {
        // logger.i(e, error: e);
      }
    }
    await Storage.setString(
      StorageKeyString.defaultWebRTCServers,
      jsonEncode(KeychatGlobal.webrtcIceServers),
    );
    return KeychatGlobal.webrtcIceServers;
  }

  static Future<Identity?> handleAmberLogin() async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

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
                  hintText: 'Nickname',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (c) async {
                  final identity = await _submitAmberLogin(controller);
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
              final identity = await _submitAmberLogin(controller);
              Get.back(result: identity);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  static String hexToString(String input) {
    return String.fromCharCodes(
      List.generate(
        input.length ~/ 2,
        (index) =>
            int.parse(input.substring(index * 2, index * 2 + 2), radix: 16),
      ),
    );
  }

  static List<int> hexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      throw const FormatException(
        'Hex string must have an even number of characters.',
      );
    }
    final bytes =
        <
          int
        >[]; // Use List<int> instead of Uint8List for return type consistency
    for (var i = 0; i < hex.length; i += 2) {
      final hexByte = hex.substring(i, i + 2);
      final byte = int.tryParse(hexByte, radix: 16);
      if (byte == null) {
        throw FormatException('Invalid hex character in: $hexByte');
      }
      bytes.add(byte);
    }
    return bytes;
  }

  static Uint8List hexToUint8List(String input) {
    if (input.length % 2 != 0) {
      throw const FormatException(
        'Hex string must have an even number of characters.',
      );
    }
    return Uint8List.fromList(
      List.generate(input.length ~/ 2, (index) {
        final hexByte = input.substring(index * 2, index * 2 + 2);
        final byte = int.tryParse(hexByte, radix: 16);
        if (byte == null) {
          throw FormatException('Invalid hex character in: $hexByte');
        }
        return byte;
      }),
    );
  }

  static void hideKeyboard(BuildContext context) {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  static Future<void> initLoggger(Directory directory) async {
    logger = Logger(
      filter: kReleaseMode ? MyLogFilter() : null,
      printer: PrettyPrinter(
        dateTimeFormat: kDebugMode
            ? DateTimeFormat.onlyTime
            : DateTimeFormat.dateAndTime,
        colors: false,
        methodCount: kReleaseMode ? 1 : 5,
      ),
      output: kReleaseMode
          ? LogFileOutputs(await Utils.createLogFile(directory.path))
          : null,
    );

    loggerNoLine = logger = Logger(
      filter: kReleaseMode ? MyLogFilter() : null,
      printer: PrettyPrinter(
        dateTimeFormat: kDebugMode
            ? DateTimeFormat.onlyTime
            : DateTimeFormat.dateAndTime,
        colors: false,
        methodCount: kReleaseMode ? 1 : 0,
      ),
      output: kReleaseMode
          ? LogFileOutputs(await Utils.createLogFile(directory.path))
          : null,
    );
  }

  static String randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  static int randomInt(int length) {
    const chars = '0123456789';
    final random = Random.secure();
    return int.parse(
      List.generate(
        length,
        (index) => chars[random.nextInt(chars.length)],
      ).join(),
    );
  }

  static String regrexLetter(String account, [int length = 2]) {
    return account.length > length - 1 ? account.substring(0, length) : account;
  }

  static void showInfoDialog(String content, [String? title]) {
    Get.dialog(
      CupertinoAlertDialog(
        title: Text(title ?? 'Info'),
        content: Text(content),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Get.back<void>();
            },
          ),
        ],
      ),
    );
  }

  static void showTwoActionDialog({
    required String content,
    required String btnText,
    required Function onPressed,
    String? title,
  }) {
    Get.dialog(
      CupertinoAlertDialog(
        title: Text(title ?? 'Info'),
        content: Text(content),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Get.back<void>();
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
      ),
    );
  }

  static String stringToHex(String input) {
    return input.codeUnits
        .map((unit) => unit.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static String unit8ListToHex(Uint8List input) {
    return input.map((unit) => unit.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<List<String>> waitRelayOnline({
    List<String>? defaultRelays,
  }) async {
    var ws = getGetxController<WebsocketService>();

    for (var initAttempts = 1; initAttempts <= 5; initAttempts++) {
      if (ws != null) break;
      logger.i(
        'Waiting for WebsocketService to initialize... ($initAttempts/5)',
      );
      await Future.delayed(const Duration(milliseconds: 300));
      ws = getGetxController<WebsocketService>();
    }

    if (ws == null) {
      logger.e('Failed to initialize WebsocketService');
      return [];
    }
    var onlineRelays = ws.getOnlineSocketString();
    var activeRelays = defaultRelays ?? [];
    if (activeRelays.isEmpty) {
      activeRelays = ws.getActiveRelayString();
    }
    final result = getIntersection(onlineRelays, activeRelays);
    for (
      var checkRelayOnlineTimes = 0;
      checkRelayOnlineTimes < 5;
      checkRelayOnlineTimes++
    ) {
      if (result.isNotEmpty) {
        return result;
      }
      final debug = {
        checkRelayOnlineTimes: checkRelayOnlineTimes,
        'onlineRelays': onlineRelays,
        'activeRelays': activeRelays,
      };
      logger.i('Waiting for relays to be available... $debug');
      await Future.delayed(const Duration(seconds: 1));
      onlineRelays = ws.getOnlineSocketString();
    }
    return result;
  }

  static String _getDisplayName(String account, int nameLength) {
    if (account.isEmpty) return ''; // Handle empty string
    if (account.length <= nameLength) return account;
    if (account.contains(' ')) {
      final firstWord = account.split(' ').first;
      return firstWord.length > nameLength
          ? firstWord.substring(0, nameLength)
          : firstWord;
    }
    if (account.contains('-')) {
      final firstPart = account.split('-').first;
      return firstPart.length > nameLength
          ? firstPart.substring(0, nameLength)
          : firstPart;
    }
    if (account.contains('_')) {
      final firstPart = account.split('_').first;
      return firstPart.length > nameLength
          ? firstPart.substring(0, nameLength)
          : firstPart;
    }
    if (RegExp(r'^[a-zA-Z0-9]+$').hasMatch(account)) {
      final parts = account.split(RegExp(r'(?=[A-Z])|\s+'));
      final firstPart = parts.isNotEmpty ? parts.first : account;
      return firstPart.length > nameLength
          ? firstPart.substring(0, nameLength)
          : firstPart;
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
    TextEditingController controller,
  ) async {
    final name = controller.text.trim();

    if (name.isEmpty) {
      EasyLoading.showError('Username is required');
      return null;
    }
    final pubkey = await SignerService.instance.getPublicKey();
    if (pubkey == null) {
      EasyLoading.showError('Amber Not Authorized');
      return null;
    }

    EasyLoading.show(status: 'Loading...');

    try {
      final res = await IdentityService.instance.createIdentityByAmberPubkey(
        name: name,
        pubkey: pubkey,
      );
      EasyLoading.dismiss();

      return res;
    } catch (e, s) {
      logger.e('Failed to create identity: $e', stackTrace: s);
      EasyLoading.showError('Failed to create identity: $e');
    }
    return null;
  }

  static Future<void> offAndToNamedRoom(Room room, [dynamic arguments]) async {
    if (GetPlatform.isMobile) {
      await Get.offAndToNamed('/room/${room.id}', arguments: arguments ?? room);
      return;
    }

    Get.back<void>();
    Get.find<DesktopController>().activeChatTabAndToRoom(room);
    await Get.toNamed(
      '/room/${room.id}',
      arguments: arguments ?? room,
      id: GetXNestKey.room,
    );
  }

  static Future<void> offAllNamedRoom([dynamic arguments]) async {
    if (GetPlatform.isMobile) {
      await Get.offAllNamed(Routes.root, arguments: arguments);
      return;
    }
    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }
    await Get.offAndToNamed(
      Routes.roomEmpty,
      arguments: arguments,
      id: GetXNestKey.room,
    );
  }

  static Future<void> toNamedRoom(Room room, [dynamic arguments]) async {
    if (GetPlatform.isMobile) {
      if (Get.currentRoute == '/room/${room.id}') {
        logger.i('Already in room ${room.id}, no need to navigate again');
        return;
      }
      await Get.toNamed('/room/${room.id}', arguments: arguments ?? room);
      return;
    }
    // nothing changed
    if (room.id == Get.find<DesktopController>().selectedRoom.value.id) {
      return;
    }
    Get.find<DesktopController>().activeChatTabAndToRoom(room);
    await Get.offAllNamed(
      '/room/${room.id}',
      arguments: arguments ?? room,
      id: GetXNestKey.room,
    );
  }

  // Catch and log errors to file
  static Future<void> logErrorToFile(String errorDetails) async {
    if (kDebugMode) return;
    try {
      final appFolder = await getAppFolder();
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final errorFilePath = '${appFolder.path}/errors/$dateStr.txt';
      final file = File(errorFilePath);

      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }

      await file.writeAsString('$errorDetails\n\n', mode: FileMode.append);
      // logger.e('Error written to $errorFilePath');
    } catch (e) {
      logger.e('Failed to write error to file: $e');
    }
  }

  static void enableImportDB() {
    Get.dialog(
      CupertinoAlertDialog(
        title: const Text('Alert'),
        content: const Text(
          'Once executed, this action will permanently delete all your local data. Proceed with caution to avoid unintended consequences.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Get.back<void>();
            },
          ),
          CupertinoDialogAction(
            child: const Text('Confirm'),
            onPressed: () async {
              final file = await DbSetting().importFile();
              if (file == null) {
                return;
              }
              _showEnterDecryptionPwdDialog(file);
            },
          ),
        ],
      ),
    );
  }

  static void _showEnterDecryptionPwdDialog(File file) {
    final passwordController = TextEditingController();

    Get.dialog(
      CupertinoAlertDialog(
        title: const Text('Enter decryption password'),
        content: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 15),
          child: Column(
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Get.back<void>();
            },
            child: const Text('Cancel'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                EasyLoading.showError('Password can not be empty');
                return;
              }

              try {
                EasyLoading.show(status: 'Decrypting...');
                final success = await DbSetting().importDB(
                  passwordController.text,
                  file,
                );
                EasyLoading.dismiss();
                if (!success) {
                  EasyLoading.showError('Decryption failed');
                  return;
                }
                EasyLoading.showSuccess('Decryption successful');
                Get.dialog(
                  CupertinoAlertDialog(
                    title: const Text('Restart Required'),
                    content: const Text(
                      'The app needs to restart to reload the database. Please restart the app manually.',
                    ),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text(
                          'Exit',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () {
                          exit(0); // Exit the app
                        },
                      ),
                    ],
                  ),
                );
              } catch (e, s) {
                logger.e('Decryption error: $e', stackTrace: s);
                EasyLoading.showError('Decryption failed');
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  static Widget getAvatarByIdentity(Identity identity, {double size = 48}) {
    final cacheKey = 'avatar_dot_${identity.secp256k1PKHex}_$size';
    if (_avatarWidgetCache.containsKey(cacheKey)) {
      return _avatarWidgetCache[cacheKey]!;
    }
    late Widget avatarWidget;
    final avatarPath = identity.avatarLocalPath;
    // Check if local avatar file exists
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final avatarFile = File(Utils.appFolder.path + avatarPath);
      // logger.d('Loading local avatar from: ${avatarFile.path}');
      if (avatarFile.existsSync()) {
        avatarWidget = Utils.getAvatarByImageFile(avatarFile, size: size);
        _avatarWidgetCache[cacheKey] = avatarWidget;
        return avatarWidget;
      }
    }

    // Fallback to random avatar if no local file or file doesn't exist
    return Utils.getRandomAvatar(
      identity.secp256k1PKHex,
      size: size,
    );
  }

  static Widget selectIdentityIconButton({
    required Identity identity,
    required void Function(Identity? selected) onChanged,
  }) {
    // Use local state that persists across rebuilds
    return GetBuilder<_IdentityButtonController>(
      init: _IdentityButtonController(identity),
      builder: (controller) {
        return TextButton.icon(
          onPressed: () async {
            final selected = await Get.bottomSheet<Identity>(
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              const SelectIdentityForward('Select a Identity'),
            );
            if (selected == null) return;

            controller.updateIdentity(selected);
            onChanged(selected);
          },
          icon: const Icon(Icons.swap_horiz),
          label: Text(controller.currentIdentity.displayName),
        );
      },
    );
  }
}

// Add this helper controller class at the end of the file
class _IdentityButtonController extends GetxController {
  _IdentityButtonController(this.currentIdentity);

  Identity currentIdentity;

  void updateIdentity(Identity identity) {
    currentIdentity = identity;
    update();
  }
}
