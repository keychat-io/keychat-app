import 'package:app/desktop/DesktopController.dart';
import 'package:app/global.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/cashu_page.dart';

class DeskEcash extends GetView<DesktopController> {
  const DeskEcash({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
        key: Get.nestedKey(GetXNestKey.ecash),
        initialRoute: '/ecash',
        onGenerateRoute: (RouteSettings settings) {
          if (settings.name == '/ecash') {
            return GetPageRoute(page: () => CashuPage());
          }
          return null;
        });
  }
}
