import 'package:app/controller/setting.controller.dart';
import 'package:app/global.dart';
import 'package:app/page/browser/BrowserSetting.dart';
import 'package:app/page/login/AccountSetting/AccountSetting_bindings.dart';
import 'package:app/page/login/SelectModeToCreateID.dart';
import 'package:app/page/routes.dart';
import 'package:app/page/setting/app_general_setting.dart';
import 'package:app/page/setting/more_chat_setting.dart';
import 'package:flutter/foundation.dart';
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

import 'AccountSetting/AccountSetting_page.dart';

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
        floatingActionButton: kDebugMode
            ? ElevatedButton(
                onPressed: () async {
                  // Simulate an error in an async operation
                  await Future.delayed(Duration(seconds: 1));
                  throw Exception('This is a simulated async error!');
                },
                child: Text('Test'),
              )
            : null,
        body: Container(
          padding: EdgeInsets.only(
              bottom: GetPlatform.isMobile ? kMinInteractiveDimension : 0),
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
                              Get.bottomSheet(
                                  clipBehavior: Clip.antiAlias,
                                  shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(4))),
                                  const SelectModeToCreateId());
                            })
                      ]),
                  if (GetPlatform.isMobile)
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
                        ]),
                  SettingsSection(
                    margin: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16, vertical: 16),
                    tiles: [
                      SettingsTile.navigation(
                        leading: const Icon(CupertinoIcons.chat_bubble),
                        title: const Text("Chat Settings"),
                        onPressed: (context) async {
                          Get.to(() => const MoreChatSetting(),
                              id: GetPlatform.isDesktop
                                  ? GetXNestKey.setting
                                  : null);
                        },
                      ),
                      if (!GetPlatform.isLinux)
                        SettingsTile.navigation(
                            title: const Text("Browser Settings"),
                            leading: const Icon(CupertinoIcons.compass),
                            onPressed: (context) async {
                              Get.to(() => const BrowserSetting(),
                                  id: GetPlatform.isDesktop
                                      ? GetXNestKey.setting
                                      : null);
                            }),
                      SettingsTile.navigation(
                        leading: const Icon(CupertinoIcons.settings),
                        title: const Text("App Settings"),
                        onPressed: (context) {
                          Get.to(() => const AppGeneralSetting(),
                              id: GetPlatform.isDesktop
                                  ? GetXNestKey.setting
                                  : null);
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
    String platform = GetPlatform.isAndroid
        ? 'android'
        : GetPlatform.isIOS
            ? 'ios'
            : GetPlatform.isMacOS
                ? 'macos'
                : GetPlatform.isWindows
                    ? 'windows'
                    : GetPlatform.isLinux
                        ? 'linux'
                        : 'ios';

    String newVersion =
        homeController.remoteAppConfig['${platform}Version'] ?? "0.0.0+0";

    String localVersion =
        homeController.remoteAppConfig['appVersion'] ?? '0.0.0+0';

    var n = Version.parse(newVersion);
    var l = Version.parse(localVersion);
    bool isNewVersionAvailable = n.compareTo(l) > 0;
    return GestureDetector(
      onTap: () {
        if (GetPlatform.isIOS) {
          const url = 'itms-beta://testflight.apple.com';
          launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
          return;
        }
        const url = 'https://keychat.io';
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(localVersion),
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
              httpAvatar: identity.avatarFromRelay, height: 30, width: 30),
          title: Text(
            identity.displayName,
            overflow: TextOverflow.ellipsis,
            style: i == 0
                ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary)
                : Theme.of(context).textTheme.bodyLarge,
          ),
          value: Text(getPublicKeyDisplay(identity.npub, 6)),
          onPressed: (context) async {
            Get.to(() => AccountSettingPage(),
                arguments: identity,
                binding: AccountSettingBindings(identity),
                id: GetPlatform.isDesktop ? GetXNestKey.setting : null);
          }));
    }
    return res;
  }
}
