import 'package:keychat/desktop/DesktopController.dart';
import 'package:keychat/global.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/bitcoin_wallet_main.dart';
import 'package:keychat_ecash/unified_wallet/unified_wallet_controller.dart';

class DeskEcash extends GetView<DesktopController> {
  const DeskEcash({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: Get.nestedKey(GetXNestKey.ecash),
      initialRoute: '/bitcoin_wallets',
      onGenerateRoute: (RouteSettings settings) {
        if (settings.name == '/bitcoin_wallets') {
          Utils.getOrPutGetxController(
            create: UnifiedWalletController.new,
            permanent: true,
          );
          return GetPageRoute(page: BitcoinWalletMain.new);
        }

        return null;
      },
    );
  }
}
