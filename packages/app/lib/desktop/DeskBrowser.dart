import 'package:app/desktop/DesktopController.dart';
import 'package:app/global.dart';
import 'package:app/page/browser/Browser_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeskBrowser extends GetView<DesktopController> {
  const DeskBrowser({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
        key: Get.nestedKey(GetXNestKey.browser),
        initialRoute: '/browser',
        onGenerateRoute: (RouteSettings settings) {
          if (settings.name == '/browser') {
            return GetPageRoute(page: () => BrowserPage());
          }
          return null;
        });
  }
}
