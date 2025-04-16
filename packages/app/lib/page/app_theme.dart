import 'package:app/page/theme.dart';
import 'package:flutter/material.dart';

class AppThemeCustom {
  static light() {
    return ThemeData(
        splashColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        useMaterial3: true,
        colorScheme: MaterialTheme.lightScheme());
  }

  static dark() {
    return ThemeData(
        splashColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        useMaterial3: true,
        colorScheme: MaterialTheme.darkScheme());
  }
}
