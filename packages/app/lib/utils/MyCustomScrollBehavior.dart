import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart' show MaterialScrollBehavior;

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };
}
