import 'dart:io' show HttpClient, HttpClientResponse, HttpClientRequest;
import 'dart:math' show Random;
import 'package:app/page/theme.dart';
import 'package:app/utils.dart';
import 'package:badges/badges.dart' as badges;

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:intl/intl.dart';
import 'package:linkify/linkify.dart' as linkifys;
import 'package:url_launcher/url_launcher.dart';
import 'package:app/models/models.dart';

double screenWidth(BuildContext context) {
  return MediaQuery.of(context).size.width;
}

double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;

String getCurrentTime() {
  return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
}

Widget showBaseImageBigWithName(String account, String name) {
  return genAvatorUserLetterWithNewName(account, name, 20, 16);
}

String regrexLetter(String account) {
  return account.length > 1 ? account.substring(0, 2) : account;
}

Widget getAvatarDot(Room room, {double width = 50}) {
  int newMessageCount = room.unReadCount;
  RoomType chatType = room.type;

  late Widget child;
  if (chatType == RoomType.group) {
    String account = room.getRoomName();
    List<Color> colors = _getGroupColor(room.groupType);
    child = getAvatorByName(account,
        room: room, width: width, borderRadius: 12, backgroudColors: colors);
  } else {
    child = getRandomAvatar(room.toMainPubkey, height: width, width: width);
  }
  if (room.unReadCount == 0) return child;

  // mute room
  if (room.isMute) {
    return badges.Badge(
      position: badges.BadgePosition.topEnd(top: -5, end: -5),
      child: child,
    );
  }
  return badges.Badge(
    badgeContent: Text(
      "$newMessageCount",
      style: const TextStyle(color: Colors.white),
    ),
    position: badges.BadgePosition.topEnd(top: -8, end: -5),
    child: child,
  );
}

List<Color> _getGroupColor(GroupType groupType) {
  switch (groupType) {
    case GroupType.mls:
      return [const Color(0xffEC6E0E), const Color(0xffDF4D9E)];
    case GroupType.kdf:
      return [const Color(0xffCE9FFC), const Color(0xff7367F0)];
    case GroupType.shareKey:
      return [const Color(0xff823C70), const Color(0xffAF362D)];
    case GroupType.sendAll:
      return [const Color(0xff945BF3), const Color(0xff713CD0)];
    default:
  }
  return [const Color(0xff02F700), const Color(0xff439368)];
}

Widget getAvatorByName(String account,
    {double width = 45,
    double fontSize = 18,
    Room? room,
    double borderRadius = 100,
    List<Color>? backgroudColors}) {
  String letter = regrexLetter(account);
  Widget child = Center(
    child: Text(
      letter.toUpperCase(),
      style: TextStyle(fontSize: fontSize, color: Colors.white),
    ),
  );
  if (room != null) {
    if (room.isShareKeyGroup) {
      child = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            letter.toUpperCase(),
            style: TextStyle(fontSize: fontSize, color: Colors.white),
          ),
          Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(0.5), BlendMode.srcIn),
                child: Image.asset(
                  // "assets/images/${room.groupType == GroupType.shareKey ? 'key' : 'group'}.png",
                  "assets/images/key.png",
                  fit: BoxFit.fitWidth,
                  width: 24,
                  height: 12,
                ),
              ))
        ],
      );
    }
  }
  return Container(
      width: width,
      height: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
            colors: backgroudColors ??
                [const Color(0xff713CD0), const Color(0xff945BF3)]),
      ),
      child: child);
}

genAvatorUserLetterWithNewName(
    String account, String name, double radius, double size) {
  String letter = regrexLetter(account);

  return Column(
    children: [
      CircleAvatar(
        foregroundColor: Colors.white,
        backgroundColor: MaterialTheme.lightScheme().primary,
        radius: radius,
        child: Text(
          letter.toUpperCase(),
          style: TextStyle(fontSize: size),
        ),
      ),
      Text(
        name,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

String generateRandomString(int length) {
  final random = Random();
  const availableChars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz';
  final randomString = List.generate(length,
      (index) => availableChars[random.nextInt(availableChars.length)]).join();

  return randomString;
}

String formatTimeMsgInt(int millisecond) {
  int milliNow = DateTime.now().millisecondsSinceEpoch;
  int year = DateTime.now().year;
  DateTime formatDt = DateTime.fromMillisecondsSinceEpoch(millisecond);
  int yearIn = formatDt.year;
  int month = formatDt.month;
  int day = formatDt.day;
  int week = formatDt.weekday;
  int hour = formatDt.hour;
  int minute = formatDt.minute;
  String monStr, dayStr, hourStr, mmStr;
  String yearStr = yearIn.toString().substring(2, 4);
  if (hour < 10) {
    hourStr = "0$hour";
  } else {
    hourStr = "$hour";
  }
  if (minute < 10) {
    mmStr = "0$minute";
  } else {
    mmStr = "$minute";
  }
  if (month < 10) {
    monStr = "0$month";
  } else {
    monStr = "$month";
  }
  if (day < 10) {
    dayStr = "0$day";
  } else {
    dayStr = "$day";
  }
  // String h_m = DateUtil.formatDate(formatDt, format: DateFormats.h_m);
  if (milliNow - millisecond <= 24 * 3600 * 1000) {
    if (hour >= 0 && hour < 12) {
      return "$hourStr:$mmStr AM";
    } else {
      return "$hourStr:$mmStr PM";
    }
  } else if (milliNow - millisecond <= 48 * 3600 * 1000) {
    return "$hourStr:$mmStr Yday";
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

String formatTimeMsg(DateTime formatDt) {
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

String getFormatTimeForMessage(DateTime formatDt) {
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

Future<double> getWidth(BuildContext context) async {
  return MediaQuery.of(context).size.width;
}

void easyLoadingToast(String content) {
  EasyLoading.showToast(content, duration: const Duration(milliseconds: 100));
}

Future<void> onOpen(LinkableElement link) async {
  if (await canLaunchUrl(Uri.parse(link.url))) {
    await launchUrl(Uri.parse(link.url));
  } else {
    throw 'Could not launch $link';
  }
}

String messageStatus(Message message) {
  if (message.sent == SendStatusType.failed) {
    return "❗️${message.content}";
  }
  int milliNow = DateTime.now().millisecondsSinceEpoch;
  int millisecond = message.createdAt.millisecondsSinceEpoch;
  int subMill = milliNow - millisecond;
  if (message.sent == SendStatusType.sending && subMill >= 10000) {
    return "❗️${message.content}";
  }
  return message.content;
}

linkifyContent(String content) {
  List list = [];
  var links =
      linkifys.linkify(content, options: const LinkifyOptions(humanize: false));
  for (var element in links) {
    if (element.toString().contains("LinkElement")) {
      list.add(element.text);
    }
  }
  return list;
}

Future<bool> validateImage(String imageUrl) async {
  HttpClient httpClient = HttpClient();
  Uri uri = Uri.parse(imageUrl);
  HttpClientRequest request = await httpClient.getUrl(uri);
  HttpClientResponse response = await request.close();
  String contentType = response.headers.contentType.toString();
  return checkIfImage(contentType);
}

bool imageCheck(String imageUrl) {
  bool flag = false;
  validateImage(imageUrl).then((value) => flag = value);
  return flag;
}

bool checkIfImage(String param) {
  if (param == 'image/jpeg' || param == 'image/png' || param == 'image/gif') {
    return true;
  }
  return false;
}

bool regexLetterNumber(String account) {
  RegExp regex = RegExp(r"^[a-zA-Z0-9]+$");
  return regex.hasMatch(account);
}

bool nostrKeyInputCheck(String account, {bool pubkey = true}) {
  final pubkeyStr = pubkey ? "public key" : "private key";
  if (account.isEmpty) {
    EasyLoading.showError("Please input $pubkeyStr");
    return false;
  }
  if (account.length == 64) {
    if (account.startsWith('npub') || account.startsWith('nsec')) {
      EasyLoading.showError("Input is incorrect");
      return false;
    }
    return true;
  }

  return true;
}
