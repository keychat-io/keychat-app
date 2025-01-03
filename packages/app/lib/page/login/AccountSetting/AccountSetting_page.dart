import 'package:app/controller/home.controller.dart';
import 'package:app/models/browser/browser_connect.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/identity.dart';
import 'package:app/page/browser/BrowserConnectedWebsite.dart';
import 'package:app/page/components.dart';
import 'package:app/page/routes.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:settings_ui/settings_ui.dart';
import './AccountSetting_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class AccountSettingPage extends GetView<AccountSettingController> {
  const AccountSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            centerTitle: true,
            title: Obx(() => Text(controller.identity.value.displayName))),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(
                  top: 0, left: 16, right: 16, bottom: 24),
              child: Obx(() => Column(children: [
                    Center(
                      child: Utils.getRandomAvatar(
                          controller.identity.value.secp256k1PKHex,
                          height: 64,
                          width: 64),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                              text: controller.identity.value.npub));
                          EasyLoading.showSuccess("Copied");
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.1),
                          ),
                          child: Text(
                            controller.identity.value.npub,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        )),
                  ])),
            ),
            Obx(() => Expanded(
                    child: SettingsList(
                  platform: DevicePlatform.iOS,
                  sections: [
                    SettingsSection(
                      tiles: [
                        if (kDebugMode)
                          SettingsTile(
                            leading: const Icon(CupertinoIcons.person),
                            title: const Text("Hex"),
                            value: Text(getPublicKeyDisplay(
                                controller.identity.value.secp256k1PKHex)),
                          ),
                        if (controller.identity.value.index == -1)
                          _getNsec(true),
                        if (controller.identity.value.index > -1)
                          SettingsTile.navigation(
                            leading: const Icon(Icons.key),
                            title: const Text("Seed Phrase"),
                            onPressed: (context) {
                              Get.bottomSheet(_idKeysWidget());
                            },
                          )
                      ],
                    ),
                    SettingsSection(
                      tiles: [
                        SettingsTile.switchTile(
                          initialValue: controller.identity.value.enableChat,
                          leading: const Icon(CupertinoIcons.chat_bubble),
                          title: const Text("Enable Chat"),
                          onToggle: (value) async {
                            EasyThrottle.throttle(
                                'enableChat', const Duration(seconds: 2),
                                () async {
                              if (value == false) {
                                int count = await DBProvider.database.identitys
                                    .filter()
                                    .enableChatEqualTo(true)
                                    .count();
                                if (count == 1) {
                                  EasyLoading.showError(
                                      "You cannot disable the last ID");
                                  return;
                                }
                              }
                              controller.identity.value.enableChat = value;
                              await IdentityService.instance
                                  .updateIdentity(controller.identity.value);
                              controller.identity.refresh();
                              Get.find<HomeController>()
                                  .loadRoomList(init: true);
                            });
                          },
                        ),
                        if (controller.identity.value.enableChat)
                          SettingsTile.navigation(
                            leading: const Icon(CupertinoIcons.qrcode),
                            title: const Text("Private Chat Key"),
                            onPressed: (context) async {
                              await showMyQrCode(
                                  context, controller.identity.value, true);
                            },
                          ),
                        if (controller.identity.value.enableChat)
                          SettingsTile.navigation(
                            leading: const Icon(CupertinoIcons.person),
                            title: const Text("NickName"),
                            value: Obx(() =>
                                Text(controller.identity.value.displayName)),
                            onPressed: (context) async {
                              await _updateIdentityNameDialog(
                                  context, controller.identity.value);
                            },
                          ),
                        if (controller.identity.value.enableChat)
                          SettingsTile.navigation(
                            leading: const Icon(
                                CupertinoIcons.person_2_square_stack_fill),
                            title: const Text("Contact List"),
                            onPressed: (context) {
                              Get.toNamed(Routes.contactList,
                                  arguments: controller.identity.value);
                            },
                          ),
                      ],
                    ),
                    SettingsSection(
                      tiles: [
                        SettingsTile.switchTile(
                          initialValue: controller.identity.value.enableBrowser,
                          leading: const Icon(CupertinoIcons.compass),
                          title: const Text("Enable Browser Login"),
                          onToggle: (value) async {
                            if (value == false) {
                              int count = await DBProvider.database.identitys
                                  .filter()
                                  .enableBrowserEqualTo(true)
                                  .count();
                              if (count == 1) {
                                EasyLoading.showError(
                                    "You cannot disable the last ID");
                                return;
                              }

                              await BrowserConnect.deleteByPubkey(
                                  controller.identity.value.secp256k1PKHex);
                            }
                            controller.identity.value.enableBrowser = value;
                            await IdentityService.instance
                                .updateIdentity(controller.identity.value);
                            controller.identity.refresh();
                          },
                        ),
                        if (controller.identity.value.enableBrowser)
                          SettingsTile(
                            leading: const Icon(Icons.web),
                            title: const Text("Logged in Websites"),
                            onPressed: (context) async {
                              Get.to(() => BrowserConnectedWebsite(
                                  controller.identity.value));
                            },
                          )
                      ],
                    ),
                    SettingsSection(
                      title: const Text('Danger Zone'),
                      tiles: [
                        SettingsTile(
                          leading: const Icon(CupertinoIcons.trash,
                              color: Colors.red),
                          title: const Text("Delete ID",
                              style: TextStyle(color: Colors.red)),
                          onPressed: (context) async {
                            Get.dialog(CupertinoAlertDialog(
                              title: const Text("Delete ID?"),
                              content: Column(
                                children: [
                                  const Text(
                                      "Please make sure you have backed up your seed phrase."),
                                  Text(
                                      "Input your name ${controller.identity.value.displayName} to confirm"),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller:
                                        controller.confirmDeleteController,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Name',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                              actions: <Widget>[
                                CupertinoDialogAction(
                                  child: const Text("Cancel"),
                                  onPressed: () {
                                    Get.back();
                                  },
                                ),
                                CupertinoDialogAction(
                                  onPressed: deleteIdentity,
                                  child: const Text(
                                    "Delete",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ));
                          },
                        ),
                      ],
                    ),
                  ],
                )))
          ],
        ));
  }

  SettingsTile _getNsec(bool showIcon) {
    return SettingsTile.navigation(
      leading: showIcon ? const Icon(Icons.key) : null,
      title: const Text("Nsec"),
      onPressed: (c) async {
        var sk = await controller.identity.value.getSecp256k1SKHex();
        var nsec = rust_nostr.getBech32PrikeyByHex(hex: sk);
        Get.dialog(CupertinoAlertDialog(
          title: const Text("Nsec"),
          content: Text(nsec),
          actions: <Widget>[
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: nsec));
                EasyLoading.showSuccess("Copied");
                Get.back();
              },
              child: const Text("Copy"),
            ),
            CupertinoDialogAction(
              child: const Text("Close"),
              onPressed: () {
                Get.back();
              },
            ),
          ],
        ));
      },
    );
  }

  _idKeysWidget() {
    return SettingsList(platform: DevicePlatform.iOS, sections: [
      SettingsSection(
        tiles: [
          if (kDebugMode)
            SettingsTile(
              title: const Text("Secp256k1 Pubkey"),
              description:
                  Obx(() => Text(controller.identity.value.secp256k1PKHex)),
            ),
          if (kDebugMode && controller.identity.value.curve25519PkHex != null)
            SettingsTile(
              title: const Text("Curve25519 Pubkey"),
              description:
                  Text(controller.identity.value.curve25519PkHex ?? ''),
            ),
          _getNsec(false),
          SettingsTile.navigation(
            title: const Text("Seed Phrase"),
            onPressed: (context) async {
              String? mnemonic = controller.identity.value.mnemonic;
              if (mnemonic == null || mnemonic.isEmpty) {
                mnemonic = await SecureStorage.instance.getPhraseWords();
              }
              Get.dialog(CupertinoAlertDialog(
                title: const Text("Seed Phrase"),
                content: Text(mnemonic ?? ''),
                actions: <Widget>[
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: mnemonic ?? ''));
                      EasyLoading.showSuccess("Copied");
                      Get.back();
                    },
                    child: const Text("Copy"),
                  ),
                  CupertinoDialogAction(
                    child: const Text("Close"),
                    onPressed: () {
                      Get.back();
                    },
                  ),
                ],
              ));
            },
          ),
        ],
      )
    ]);
  }

  _updateIdentityNameDialog(BuildContext context, Identity identity) async {
    HomeController homeController = Get.find<HomeController>();

    await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text("Update Name"),
            content: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.only(top: 15),
              child: TextField(
                controller: controller.usernameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: <Widget>[
              CupertinoDialogAction(
                child: const Text("Cancel"),
                onPressed: () {
                  Get.back();
                },
              ),
              CupertinoDialogAction(
                child: const Text("Confirm"),
                onPressed: () async {
                  if (controller.usernameController.text.isEmpty) {
                    EasyLoading.showError("Please input a non-empty name");
                    return;
                  }
                  identity.name = controller.usernameController.text.trim();
                  await IdentityService.instance.updateIdentity(identity);
                  controller.identity.value = identity;
                  controller.identity.refresh();
                  controller.usernameController.clear();
                  await homeController.loadIdentity();
                  homeController.tabBodyDatas.refresh();
                  Get.back();
                },
              ),
            ],
          );
        });
  }

  void deleteIdentity() async {
    if (controller.confirmDeleteController.text !=
        controller.identity.value.displayName) {
      EasyLoading.showError("Name does not match");
      return;
    }
    controller.confirmDeleteController.clear();
    HomeController hc = Get.find<HomeController>();
    List<Identity> identities =
        await IdentityService.instance.getIdentityList();
    if (identities.length == 1) {
      Get.back();
      EasyLoading.showError("You cannot delete the last ID");
      return;
    }

    EcashController ec = Get.find<EcashController>();
    if (ec.currentIdentity?.id == controller.identity.value.id) {
      int balance = ec.getTotalByMints();
      if (balance > 0) {
        EasyLoading.showError('Please withdraw all balance');
        return;
      }
    }
    try {
      EasyLoading.showInfo('Deleting...');
      await IdentityService.instance.delete(controller.identity.value);
      hc.loadRoomList(init: true);

      EasyLoading.showSuccess("ID deleted");
      Get.back();
      Get.back();
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
      EasyLoading.showError(e.toString());
    }
  }
}
