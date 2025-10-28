import 'package:flutter/material.dart';

class NoticeTextWidget {
  static Container _containter(
    String text,
    Color color, {
    double fontSize = 14,
    double borderRadius = 4,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(text, style: TextStyle(fontSize: fontSize)),
    );
  }

  static Widget warning(
    String text, {
    double fontSize = 14,
    double borderRadius = 4,
  }) {
    return _containter(
      text,
      Colors.yellow,
      fontSize: fontSize,
      borderRadius: borderRadius,
    );
  }

  static Widget info(
    String text, {
    double fontSize = 14,
    double borderRadius = 4,
  }) {
    return _containter(
      text,
      Colors.blue,
      fontSize: fontSize,
      borderRadius: borderRadius,
    );
  }

  static Widget error(
    String text, {
    double fontSize = 14,
    double borderRadius = 4,
  }) {
    return _containter(
      text,
      Colors.red,
      fontSize: fontSize,
      borderRadius: borderRadius,
    );
  }

  static Widget success(
    String text, {
    double fontSize = 14,
    double borderRadius = 4,
  }) {
    return _containter(
      text,
      Colors.green,
      fontSize: fontSize,
      borderRadius: borderRadius,
    );
  }
}
