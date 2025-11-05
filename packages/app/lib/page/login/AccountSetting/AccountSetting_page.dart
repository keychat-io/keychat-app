import 'dart:async';
import 'dart:io';

import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/browser/browser_connect.dart';
import 'package:keychat/models/db_provider.dart';
import 'package:keychat/models/identity.dart';
import 'package:keychat/page/browser/BrowserConnectedWebsite.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/page/contact/contact_list_page.dart';
import 'package:keychat/page/login/AccountSetting/AccountSetting_controller.dart';
import 'package:keychat/page/profile/lightning_address_edit_dialog.dart';
import 'package:keychat/page/widgets/notice_text_widget.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:settings_ui/settings_ui.dart';

class AccountSettingPage extends GetView<AccountSettingController> {
  const AccountSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Obx(() => Text(controller.identity.value.displayName)),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                builder: (context) {
                  return SafeArea(
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 30),
                        ListTile(
                          leading: const Icon(Icons.copy),
                          title: const Text('Copy Public Key'),
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: controller.identity.value.secp256k1PKHex,
                              ),
                            );
                            await EasyLoading.showSuccess('Public Key Copied');
                            Get.back<void>();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: const Text(
                            'Delete ID',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () {
                            Get.back<void>();
                            dialogToDeleteId();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
            child: Obx(
              () => Column(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        await _pickAndSaveAvatar(
                          ImageSource.gallery,
                        );
                      },
                      child: Stack(
                        children: [
                          Obx(
                            () => Utils.getAvatarByIdentity(
                              controller.identity.value,
                              size: 84,
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (controller.identity.value.isFromSigner)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return CupertinoAlertDialog(
                                title: const Text('Notice'),
                                content: const Text(
                                  'Keychat app does not store your private key. Signing and encryption operations are handled by the Amber app.',
                                ),
                                actions: <Widget>[
                                  CupertinoDialogAction(
                                    isDefaultAction: true,
                                    onPressed: Get.back,
                                    child: const Text('OK'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: NoticeTextWidget.info(
                          'Login with Amber',
                          fontSize: 12,
                          borderRadius: 15,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: controller.identity.value.npub,
                        ),
                      );
                      EasyLoading.showSuccess('Copied');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        controller.identity.value.npub,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  if (controller.identity.value.displayAbout != null &&
                      controller.identity.value.displayAbout!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: NoticeTextWidget.info(
                        controller.identity.value.displayAbout ?? '',
                        fontSize: 12,
                        borderRadius: 8,
                      ),
                    ),
                  if (!controller.identity.value.isFromSigner)
                    FutureBuilder(
                      future: controller.identity.value.getSecp256k1SKHex(),
                      builder: (context, snapshot) {
                        if (snapshot.data == null) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: NoticeTextWidget.error(
                              'Private key not found',
                              fontSize: 12,
                              borderRadius: 15,
                            ),
                          );
                        }
                        return Container();
                      },
                    ),
                ],
              ),
            ),
          ),
          Obx(
            () => Expanded(
              child: SettingsList(
                platform: DevicePlatform.iOS,
                sections: [
                  SettingsSection(
                    tiles: [
                      SettingsTile.switchTile(
                        initialValue: controller.identity.value.enableChat,
                        leading: const Icon(CupertinoIcons.chat_bubble),
                        title: const Text('Chat ID'),
                        onToggle: (value) async {
                          EasyThrottle.throttle(
                            'enableChat',
                            const Duration(seconds: 2),
                            () async {
                              if (!value) {
                                final count = await DBProvider
                                    .database
                                    .identitys
                                    .filter()
                                    .enableChatEqualTo(true)
                                    .count();
                                if (count == 1) {
                                  EasyLoading.showError(
                                    'You cannot disable the last ID',
                                  );
                                  return;
                                }
                              }
                              controller.identity.value.enableChat = value;
                              await IdentityService.instance.updateIdentity(
                                controller.identity.value,
                              );
                              NotifyService.syncPubkeysToServer();
                              Get.find<WebsocketService>().start();
                              controller.identity.refresh();
                              Get.find<HomeController>().loadRoomList(
                                init: true,
                              );
                            },
                          );
                        },
                      ),
                      if (controller.identity.value.enableChat) ...[
                        SettingsTile.navigation(
                          leading: const Icon(CupertinoIcons.qrcode),
                          title: const Text('One-Time Link'),
                          onPressed: (context) async {
                            await showMyQrCode(
                              context,
                              controller.identity.value,
                              true,
                            );
                          },
                        ),
                        SettingsTile.navigation(
                          leading: const Icon(CupertinoIcons.link),
                          title: const Text('Universal Link'),
                          onPressed: (c) {
                            final link =
                                '${KeychatGlobal.mainWebsite}/u/?k=${controller.identity.value.npub}';
                            Clipboard.setData(ClipboardData(text: link));
                            EasyLoading.showSuccess('Copied');
                          },
                          value: const Text('Copy'),
                        ),
                        SettingsTile.navigation(
                          leading: const Icon(CupertinoIcons.person),
                          title: const Text('Name'),
                          value: Obx(
                            () => Text(controller.identity.value.displayName),
                          ),
                          onPressed: (context) async {
                            await _updateIdentityNameDialog(
                              context,
                              controller.identity.value,
                            );
                          },
                        ),
                        SettingsTile.navigation(
                          leading: const Icon(Icons.note_outlined),
                          title: const Text('Bio'),
                          onPressed: (context) async {
                            final identity = controller.identity.value;
                            final aboutController = TextEditingController(
                              text: identity.about ?? '',
                            );

                            await showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              builder: (BuildContext context) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(
                                      context,
                                    ).viewInsets.bottom,
                                    left: 16,
                                    right: 16,
                                    top: 16,
                                  ),
                                  child: SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            TextButton(
                                              onPressed: Get.back,
                                              child: const Text('Cancel'),
                                            ),
                                            const Text(
                                              'Update Bio',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            FilledButton(
                                              onPressed: () async {
                                                try {
                                                  final newAbout =
                                                      aboutController.text
                                                          .trim();
                                                  identity.about =
                                                      newAbout.isEmpty
                                                      ? null
                                                      : newAbout;
                                                  await IdentityService.instance
                                                      .updateIdentity(identity);
                                                  controller.identity.value =
                                                      identity;
                                                  controller.identity.refresh();
                                                  await Get.find<
                                                        HomeController
                                                      >()
                                                      .loadIdentity();

                                                  // Close the bottom sheet first
                                                  Navigator.of(context).pop();

                                                  // Clear controller and show success message
                                                  aboutController.clear();
                                                  EasyLoading.showSuccess(
                                                    'Bio updated successfully',
                                                  );
                                                } catch (e) {
                                                  // Handle error but still close the sheet
                                                  Navigator.of(context).pop();
                                                  aboutController.clear();
                                                  EasyLoading.showError(
                                                    'Failed to update bio: $e',
                                                  );
                                                }
                                              },
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        TextField(
                                          controller: aboutController,
                                          autofocus: true,
                                          maxLines: 5,
                                          maxLength: 200,
                                          textInputAction:
                                              TextInputAction.newline,
                                          decoration: const InputDecoration(
                                            labelText: 'Bio',
                                            border: OutlineInputBorder(),
                                            hintText:
                                                'Tell us about yourself...',
                                            alignLabelWithHint: true,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        SettingsTile.navigation(
                          leading: SizedBox(
                            width: 24,
                            child: Image.asset(
                              'assets/images/lightning.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          title: const Text('Lightning Address'),
                          onPressed: (context) async {
                            final result = await Get.dialog<String>(
                              LightningAddressEditDialog(
                                identity: controller.identity.value,
                              ),
                            );

                            if (result != null) {
                              controller.identity.value.lightning = result;
                              controller.identity.refresh();
                            }
                          },
                        ),
                        SettingsTile.navigation(
                          leading: const Icon(Icons.contacts_outlined),
                          title: const Text('Contact List'),
                          onPressed: (context) {
                            Get.to(
                              () => ContactsPage(controller.identity.value),
                              id: GetPlatform.isDesktop
                                  ? GetXNestKey.setting
                                  : null,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                  SettingsSection(
                    tiles: [
                      SettingsTile.switchTile(
                        initialValue: controller.identity.value.enableBrowser,
                        leading: const Icon(CupertinoIcons.compass),
                        title: const Text('Browser ID'),
                        onToggle: (value) async {
                          if (!value) {
                            final count = await DBProvider.database.identitys
                                .filter()
                                .enableBrowserEqualTo(true)
                                .count();
                            if (count == 1) {
                              EasyLoading.showError(
                                'You cannot disable the last ID',
                              );
                              return;
                            }

                            await BrowserConnect.deleteByPubkey(
                              controller.identity.value.secp256k1PKHex,
                            );
                          }
                          controller.identity.value.enableBrowser = value;
                          await IdentityService.instance.updateIdentity(
                            controller.identity.value,
                          );
                          controller.identity.refresh();
                        },
                      ),
                      if (controller.identity.value.enableBrowser)
                        SettingsTile.navigation(
                          leading: const Icon(Icons.web),
                          title: const Text('Logged-in Websites'),
                          onPressed: (context) async {
                            Get.to(
                              () => BrowserConnectedWebsite(
                                controller.identity.value,
                              ),
                              id: GetPlatform.isDesktop
                                  ? GetXNestKey.setting
                                  : null,
                            );
                          },
                        ),
                    ],
                  ),
                  if (kDebugMode ||
                      (controller.identity.value.index == -1 &&
                          !controller.identity.value.isFromSigner) ||
                      controller.identity.value.index > -1)
                    SettingsSection(
                      title: const Text('Security'),
                      tiles: [
                        if (kDebugMode)
                          SettingsTile(
                            leading: const Icon(CupertinoIcons.person),
                            title: const Text('Hex'),
                            onPressed: (c) {
                              debugPrint(
                                controller.identity.value.secp256k1PKHex,
                              );
                            },
                            value: Text(
                              getPublicKeyDisplay(
                                controller.identity.value.secp256k1PKHex,
                              ),
                            ),
                          ),
                        if (controller.identity.value.index == -1 &&
                            !controller.identity.value.isFromSigner)
                          _getNsec(true),
                        if (controller.identity.value.index > -1)
                          SettingsTile.navigation(
                            leading: const Icon(Icons.key),
                            title: const Text('Seed Phrase'),
                            onPressed: (context) {
                              Get.bottomSheet(
                                clipBehavior: Clip.antiAlias,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                                _idKeysWidget(),
                              );
                            },
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SettingsTile _getNsec(bool showIcon) {
    return SettingsTile.navigation(
      leading: showIcon ? const Icon(Icons.key) : null,
      title: const Text('Nsec'),
      onPressed: (c) async {
        var nsec = '';
        try {
          final sk = await controller.identity.value.getSecp256k1SKHex();
          nsec = rust_nostr.getBech32PrikeyByHex(hex: sk);
        } catch (e) {
          logger.e('Failed to get Nsec: ${Utils.getErrorMessage(e)}');
          EasyLoading.showError(Utils.getErrorMessage(e));
          return;
        }
        Get.dialog(
          CupertinoAlertDialog(
            title: const Text('Nsec'),
            content: Text(nsec),
            actions: <Widget>[
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: nsec));
                  EasyLoading.showSuccess('Copied');
                  Get.back<void>();
                },
                child: const Text('Copy'),
              ),
              CupertinoDialogAction(
                onPressed: Get.back,
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  SettingsList _idKeysWidget() {
    return SettingsList(
      platform: DevicePlatform.iOS,
      sections: [
        SettingsSection(
          tiles: [
            if (kDebugMode)
              SettingsTile(
                title: const Text('Secp256k1 Pubkey'),
                description: Obx(
                  () => Text(controller.identity.value.secp256k1PKHex),
                ),
              ),
            if (kDebugMode && controller.identity.value.curve25519PkHex != null)
              SettingsTile(
                title: const Text('Curve25519 Pubkey'),
                description: Text(
                  controller.identity.value.curve25519PkHex ?? '',
                ),
              ),
            _getNsec(false),
            SettingsTile.navigation(
              title: const Text('Seed Phrase'),
              onPressed: (context) async {
                var mnemonic = controller.identity.value.mnemonic;
                if (mnemonic == null || mnemonic.isEmpty) {
                  mnemonic = await SecureStorage.instance.getPhraseWords();
                }
                Get.dialog(
                  CupertinoAlertDialog(
                    title: const Text('Seed Phrase'),
                    content: Text(mnemonic ?? ''),
                    actions: <Widget>[
                      CupertinoDialogAction(
                        isDefaultAction: true,
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: mnemonic ?? ''),
                          );
                          EasyLoading.showSuccess('Copied');
                          Get.back<void>();
                        },
                        child: const Text('Copy'),
                      ),
                      CupertinoDialogAction(
                        onPressed: Get.back,
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _updateIdentityNameDialog(
    BuildContext context,
    Identity identity,
  ) async {
    final usernameController = TextEditingController(
      text: identity.displayName,
    );
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Update Name'),
          content: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.only(top: 15),
            child: TextField(
              controller: usernameController,
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
              onPressed: Get.back,
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              child: const Text('Confirm'),
              onPressed: () async {
                if (usernameController.text.isEmpty) {
                  EasyLoading.showError('Please input a non-empty name');
                  return;
                }
                identity.name = usernameController.text.trim();
                await IdentityService.instance.updateIdentity(identity);
                controller.identity.value = identity;
                controller.identity.refresh();
                usernameController.clear();
                Get.find<HomeController>()
                  ..loadIdentity()
                  ..tabBodyDatas.refresh();
                Get.back<void>();
              },
            ),
          ],
        );
      },
    );
  }

  void dialogToDeleteId() {
    Get.dialog(
      CupertinoAlertDialog(
        title: const Text('Delete ID?'),
        content: Column(
          children: [
            const Text('Please make sure you have backed up your seed phrase.'),
            Text(
              'Input your name ${controller.identity.value.displayName} to confirm',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller.confirmDeleteController,
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
            onPressed: Get.back,
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              if (controller.confirmDeleteController.text !=
                  controller.identity.value.displayName) {
                EasyLoading.showError('Name does not match');
                return;
              }
              controller.confirmDeleteController.clear();
              final hc = Get.find<HomeController>();
              final identities = await IdentityService.instance
                  .getIdentityList();
              if (identities.length == 1) {
                Get.back<void>(); // close dialog
                EasyLoading.showError('You cannot delete the last ID');
                return;
              }

              final ec = Get.find<EcashController>();
              if (ec.currentIdentity?.id == controller.identity.value.id) {
                final balance = ec.getTotalByMints();
                if (balance > 0) {
                  EasyLoading.showError('Please withdraw all balance');
                  return;
                }
              }
              try {
                EasyLoading.showInfo('Deleting...');
                await IdentityService.instance.delete(
                  controller.identity.value,
                );
                hc.loadRoomList(init: true);

                EasyLoading.showSuccess('ID deleted');
                if (Get.isDialogOpen ?? false) {
                  Get.back<void>();
                }
                if (GetPlatform.isDesktop) {
                  Get.offAllNamed(
                    '/setting',
                    id: GetPlatform.isDesktop ? GetXNestKey.setting : null,
                  );
                } else {
                  Get.back<void>();
                }
              } catch (e, s) {
                logger.e(e.toString(), error: e, stackTrace: s);
                EasyLoading.showError(e.toString());
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSaveAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image == null) return;
      final allowedExtensions = [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'heic',
        'bmp',
        'svg',
      ];
      final ext = image.path.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(ext)) {
        EasyLoading.showError('Unsupported image format');
        return;
      }
      late Uint8List fileBytes;
      try {
        final sourceInput = await img.decodeImageFile(image.path);
        if (sourceInput == null) {
          throw Exception('Image decode failed');
        }
        // remove exif
        sourceInput.exif = img.ExifData();
        fileBytes = img.encodeJpg(sourceInput, quality: 80);
      } catch (e) {
        // fallback to original file
        fileBytes = await image.readAsBytes();
      }
      final avatarsFolder = Utils.avatarsFolder;
      final fileName = '${Utils.randomString(16)}.$ext';
      final localFileFullPath = '$avatarsFolder/$fileName';
      final localFile = await File(localFileFullPath).create();
      await localFile.writeAsBytes(fileBytes);
      controller.identity.value.avatarLocalPath = localFileFullPath
          .replaceFirst(Utils.appFolder.path, '');
      controller.identity.value.avatarRemoteUrl = null;
      controller.identity.value.avatarUpdatedAt = null;
      await IdentityService.instance.updateIdentity(controller.identity.value);
      Utils.clearAvatarCache();
      // Force refresh UI
      controller.identity.refresh();
      await EasyLoading.showSuccess('Avatar saved successfully');
      await Get.find<HomeController>().loadIdentity();
    } catch (e, s) {
      EasyLoading.showError(
        'Failed to save avatar: ${Utils.getErrorMessage(e)}',
      );
      logger.e('Avatar save error: $e', stackTrace: s);
    }
  }
}
