import 'package:app/desktop/DesktopController.dart';
import 'package:app/global.dart';
import 'package:app/page/login/me.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeskSetting extends GetView<DesktopController> {
  const DeskSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
        key: Get.nestedKey(GetXNestKey.setting),
        initialRoute: '/setting',
        onGenerateRoute: (RouteSettings settings) {
          if (settings.name == '/setting') {
            return GetPageRoute(page: () => MinePage());
          }
          return null;
        });
  }
}
