import 'package:flutter/material.dart';

class NoticeTextWidget {
  static _containter(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
      ),
    );
  }

  static Widget warning(String text) {
    return _containter(text, Colors.yellow);
  }

  static Widget info(String text) {
    return _containter(text, Colors.blue);
  }

  static Widget error(String text) {
    return _containter(text, Colors.red);
  }

  static Widget success(String text) {
    return _containter(text, Colors.green);
  }
}
