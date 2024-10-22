import 'package:app/page/theme.dart';
import 'package:flutter/material.dart';

class AppThemeCustom {
  static light() {
    return ThemeData(
        // scaffoldBackgroundColor: lightColorScheme.surface,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
            titleTextStyle: TextStyle(fontSize: 18, color: Colors.black87)),
        colorScheme: MaterialTheme.lightScheme(),
        textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 16)));
  }

  static dark() {
    return ThemeData(
        // scaffoldBackgroundColor: darkColorScheme.surface,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
            titleTextStyle: TextStyle(fontSize: 18, color: Colors.white70)),
        colorScheme: MaterialTheme.darkScheme(),
        textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 16)));
  }
}
