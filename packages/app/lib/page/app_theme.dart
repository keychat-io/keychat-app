import 'package:app/page/theme.dart';
import 'package:flutter/material.dart';

class AppThemeCustom {
  static light() {
    return ThemeData(
        splashColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionColor: Color(0xFFFDDABB),
          selectionHandleColor: Colors.orange,
        ),
        useMaterial3: true,
        colorScheme: MaterialTheme.lightScheme());
  }

  static dark() {
    return ThemeData(
        splashColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Color(0xFF896647),
          selectionHandleColor: Color(0xFF996647),
        ),
        useMaterial3: true,
        colorScheme: MaterialTheme.darkScheme());
  }
}
