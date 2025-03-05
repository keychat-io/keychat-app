import 'package:app/controller/setting.controller.dart';
import 'package:app/page/NostrWalletConnect/NostrWalletConnect_bindings.dart';
import 'package:app/page/NostrWalletConnect/NostrWalletConnect_page.dart';
import 'package:app/page/browser/BrowserSetting.dart';
import 'package:app/page/login/SelectModeToCreateID.dart';
import 'package:app/page/routes.dart';
import 'package:app/page/setting/app_general_setting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:app/controller/home.controller.dart';

import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:app/models/models.dart';
import 'package:url_launcher/url_launcher.dart';

class MinePage extends GetView<SettingController> {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    HomeController homeController = Get.find<HomeController>();
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: GestureDetector(
            child: const Text('Me'),
            onTap: () {
              homeController.troggleDebugModel();
            },
          ),
        ),
        body: Container(
          padding:
              const EdgeInsets.only(bottom: kMinInteractiveDimension * 1.5),
          child: Obx(() => SettingsList(
                platform: DevicePlatform.iOS,
                sections: [
                  SettingsSection(
                      margin: const EdgeInsetsDirectional.only(
                          start: 16, end: 16, bottom: 16, top: 0),
                      title: const Text('Chat / Browser ID'),
                      tiles: [
                        ...getIDList(context,
                            homeController.allIdentities.values.toList()),
                        SettingsTile(
                            title: const Text("Create ID"),
                            trailing: Icon(CupertinoIcons.add,
                                color: Theme.of(Get.context!)
                                    .iconTheme
                                    .color
                                    ?.withValues(alpha: 0.5),
                                size: 22),
                            onPressed: (context) async {
                              Get.bottomSheet(const SelectModeToCreateId());
                            })
                      ]),
                  SettingsSection(
                      margin: const EdgeInsetsDirectional.symmetric(
                          horizontal: 16, vertical: 16),
                      tiles: [
                        SettingsTile.navigation(
                          leading: const Icon(
                            CupertinoIcons.bitcoin,
                            color: Color(0xfff2a900),
                          ),
                          value: Text(
                              '${Utils.getGetxController<EcashController>()?.totalSats.value.toString() ?? '-'} ${EcashTokenSymbol.sat.name}'),
                          onPressed: (context) async {
                            Get.toNamed(Routes.ecash);
                          },
                          title: const Text("Bitcoin Ecash"),
                        ),
                        SettingsTile.navigation(
                          leading: SvgPicture.asset(
                            'assets/images/logo/nwc.svg',
                            fit: BoxFit.contain,
                            width: 24,
                            height: 24,
                          ),
                          title: const Text("Nostr Wallet Connect"),
                          onPressed: (context) {
                            Get.to(() => const NostrWalletConnectPage(),
                                binding: NostrWalletConnectBindings());
                          },
                        ),
                      ]),
                  SettingsSection(
                    margin: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16, vertical: 16),
                    tiles: [
                      SettingsTile.navigation(
                        leading: const Icon(CupertinoIcons.chat_bubble),
                        title: const Text("Chat Settings"),
                        onPressed: (context) async {
                          Get.toNamed(Routes.settingMore);
                        },
                      ),
                      if (!GetPlatform.isLinux)
                        SettingsTile.navigation(
                            title: const Text("Browser Settings"),
                            leading: const Icon(CupertinoIcons.compass),
                            onPressed: (context) async {
                              Get.to(() => const BrowserSetting());
                            }),
                      SettingsTile.navigation(
                        leading: const Icon(CupertinoIcons.settings),
                        title: const Text("App Settings"),
                        onPressed: (context) {
                          Get.to(() => const AppGeneralSetting());
                        },
                      ),
                    ],
                  ),
                  SettingsSection(
                    margin: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16, vertical: 16),
                    tiles: [
                      SettingsTile(
                        leading: const Icon(Icons.verified_outlined),
                        title: const Text("App Version"),
                        value: getVersionCode(homeController),
                        onPressed: (context) {},
                      ),
                    ],
                  ),
                ],
              )),
        ));
  }

  Widget getVersionCode(HomeController homeController) {
    String newVersion = (GetPlatform.isAndroid
            ? homeController.remoteAppConfig['androidVersion']
            : homeController.remoteAppConfig['iosVersion']) ??
        "0.0.0+0";
    String localVersion =
        homeController.remoteAppConfig['appVersion'] ?? '0.0.0+0';

    var n = Version.parse(newVersion);
    var l = Version.parse(localVersion);
    bool isNewVersionAvailable = n.compareTo(l) > 0;
    return GestureDetector(
      onTap: () {
        if (GetPlatform.isAndroid) {
          const url = 'https://github.com/keychat-io/keychat-app/releases';
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else if (GetPlatform.isIOS) {
          const url = 'itms-beta://testflight.apple.com';
          launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
        }
      },
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(homeController.remoteAppConfig['appVersion']),
          if (isNewVersionAvailable)
            Container(
              margin: const EdgeInsets.only(left: 5),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  List<SettingsTile> getIDList(BuildContext context, List identities) {
    List<SettingsTile> res = [];
    for (var i = 0; i < identities.length; i++) {
      Identity identity = identities[i];

      res.add(SettingsTile.navigation(
          leading: Utils.getRandomAvatar(identity.secp256k1PKHex,
              height: 30, width: 30),
          title: Text(
            identity.displayName.length > 8
                ? "${identity.displayName.substring(0, 8)}..."
                : identity.displayName,
            style: i == 0
                ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary)
                : Theme.of(context).textTheme.bodyLarge,
          ),
          value: Text(getPublicKeyDisplay(identity.npub)),
          onPressed: (context) async {
            Get.toNamed(Routes.settingMe, arguments: identity);
          }));
    }
    return res;
  }
}
