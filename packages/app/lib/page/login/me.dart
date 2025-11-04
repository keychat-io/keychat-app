import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/page/browser/BrowserSetting.dart';
import 'package:keychat/page/login/AccountSetting/AccountSetting_bindings.dart';
import 'package:keychat/page/login/AccountSetting/AccountSetting_page.dart';
import 'package:keychat/page/login/SelectModeToCreateID.dart';
import 'package:keychat/page/routes.dart';
import 'package:keychat/page/setting/app_general_setting.dart';
import 'package:keychat/page/setting/more_chat_setting.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  late HomeController homeController;
  @override
  void initState() {
    super.initState();
    homeController = Get.find<HomeController>();
  }

  @override
  Widget build(BuildContext context) {
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
                try {} catch (e) {
                  logger.e('Failed to process QR result: $e');
                }
              },
              child: const Text('Test'),
            )
          : null,
      body: Obx(
        () => SettingsList(
          platform: DevicePlatform.iOS,
          sections: [
            SettingsSection(
              margin: const EdgeInsetsDirectional.only(
                start: 16,
                end: 16,
                bottom: 16,
              ),
              title: const Text('Chat / Browser ID'),
              tiles: [
                ...getIDList(
                  context,
                  homeController.allIdentities.values.toList(),
                ),
                SettingsTile(
                  title: const Text('Create ID'),
                  trailing: Icon(
                    CupertinoIcons.add,
                    color: Theme.of(
                      Get.context!,
                    ).iconTheme.color?.withValues(alpha: 0.5),
                    size: 22,
                  ),
                  onPressed: (context) async {
                    Get.bottomSheet(
                      clipBehavior: Clip.antiAlias,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      const SelectModeToCreateId(),
                    );
                  },
                ),
              ],
            ),
            if (GetPlatform.isMobile)
              SettingsSection(
                tiles: [
                  SettingsTile.navigation(
                    leading: const Icon(
                      CupertinoIcons.bitcoin,
                      color: Color(0xfff2a900),
                    ),
                    value: Text(
                      '${Utils.getGetxController<EcashController>()?.totalSats.value.toString() ?? '-'} ${EcashTokenSymbol.sat.name}',
                    ),
                    onPressed: (context) async {
                      Get.toNamed(Routes.ecash);
                    },
                    title: const Text('Bitcoin Ecash'),
                  ),
                ],
              ),
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  leading: const Icon(CupertinoIcons.chat_bubble),
                  title: const Text('Chat Settings'),
                  onPressed: (context) async {
                    Get.to(
                      () => const MoreChatSetting(),
                      id: GetPlatform.isDesktop ? GetXNestKey.setting : null,
                    );
                  },
                ),
                if (!GetPlatform.isLinux)
                  SettingsTile.navigation(
                    title: const Text('Browser Settings'),
                    leading: const Icon(CupertinoIcons.compass),
                    onPressed: (context) async {
                      Get.to(
                        () => const BrowserSetting(),
                        id: GetPlatform.isDesktop ? GetXNestKey.setting : null,
                      );
                    },
                  ),
                SettingsTile.navigation(
                  leading: const Icon(CupertinoIcons.settings),
                  title: const Text('App Settings'),
                  onPressed: (context) {
                    Get.to(
                      () => const AppGeneralSetting(),
                      id: GetPlatform.isDesktop ? GetXNestKey.setting : null,
                    );
                  },
                ),
              ],
            ),
            SettingsSection(
              tiles: [
                SettingsTile(
                  leading: const Icon(Icons.verified_outlined),
                  title: const Text('App Version'),
                  value: getVersionCode(homeController),
                  onPressed: (context) {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget getVersionCode(HomeController homeController) {
    final platform = GetPlatform.isAndroid
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

    final newVersion =
        homeController.remoteAppConfig['${platform}Version'] as String? ??
        '0.0.0+0';

    final localVersion =
        homeController.remoteAppConfig['appVersion'] as String? ?? '0.0.0+0';

    final n = Version.parse(newVersion);
    final l = Version.parse(localVersion);
    final isNewVersionAvailable = n.compareTo(l) > 0;
    return GestureDetector(
      onTap: () {
        if (GetPlatform.isIOS) {
          const url = 'https://apps.apple.com/app/keychat-io/id6447493752';
          launchUrl(Uri.parse(url));
          return;
        }
        const url = 'https://github.com/keychat-io/keychat-app/releases';
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

  List<SettingsTile> getIDList(
    BuildContext context,
    List<Identity> identities,
  ) {
    final res = <SettingsTile>[];
    for (var i = 0; i < identities.length; i++) {
      final identity = identities[i];

      res.add(
        SettingsTile.navigation(
          leading: Utils.getAvatarByIdentity(identity, size: 32),
          title: Text(
            identity.displayName,
            overflow: TextOverflow.ellipsis,
            style: i == 0
                ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : Theme.of(context).textTheme.bodyLarge,
          ),
          value: Text(getPublicKeyDisplay(identity.npub)),
          onPressed: (context) async {
            Get.to(
              AccountSettingPage.new,
              arguments: identity,
              binding: AccountSettingBindings(identity),
              id: GetPlatform.isDesktop ? GetXNestKey.setting : null,
            );
          },
        ),
      );
    }
    return res;
  }
}
