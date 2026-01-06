import 'package:keychat/desktop/DesktopController.dart';
import 'package:keychat/global.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/desktop/wallet_main_desktop.dart';
import 'package:keychat_ecash/cashu_page.dart';
import 'package:keychat_nwc/nwc/nwc_page.dart';

class DeskEcash extends GetView<DesktopController> {
  const DeskEcash({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: Get.nestedKey(GetXNestKey.ecash),
      initialRoute: '/ecash',
      onGenerateRoute: (RouteSettings settings) {
        if (settings.name == '/ecash') {
          return GetPageRoute(page: WalletMainDesktop.new);
        }
        // Standalone routes for individual pages
        if (settings.name == '/cashu') {
          return GetPageRoute(page: CashuPage.new);
        }
        if (settings.name == '/nwc') {
          return GetPageRoute(page: NwcPage.new);
        }
        return null;
      },
    );
  }
}
