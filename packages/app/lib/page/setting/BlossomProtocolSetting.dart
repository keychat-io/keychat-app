import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/service/storage.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class BlossomProtocolSetting extends StatefulWidget {
  const BlossomProtocolSetting({super.key});

  @override
  _BlossomProtocolSettingState createState() => _BlossomProtocolSettingState();
}

class _BlossomProtocolSettingState extends State<BlossomProtocolSetting> {
  List<String> selected = [];
  Identity selectedIdentity =
      Get.find<HomeController>().allIdentities.values.first;
  bool isEditMode = false;
  late String selectedPaymentPubkey;
  List<String> builtInMedias = [
    "https://void.cat",
    "https://cdn.satellite.earth",
    "https://cdn.nostrcheck.me",
    "https://nostr.download",
    "https://nostrmedia.com",
  ];

  @override
  void initState() {
    selectedPaymentPubkey = selectedIdentity.secp256k1PKHex;
    super.initState();
    init();
  }

  Future<void> init() async {
    String? savedSelectedPaymentPubkey =
        await Storage.getString(StorageKeyString.selectedPaymentPubkey);
    if (savedSelectedPaymentPubkey != null) {
      Identity? exist = Get.find<HomeController>()
          .allIdentities
          .values
          .toList()
          .firstWhereOrNull((identity) =>
              identity.secp256k1PKHex == savedSelectedPaymentPubkey);
      if (exist != null) {
        logger.d(exist.secp256k1PKHex);
        setState(() {
          selectedPaymentPubkey = savedSelectedPaymentPubkey;
          selectedIdentity = exist;
        });
      }
    }
    List<String> savedServers =
        await Storage.getStringList(StorageKeyString.blossomProtocolServers);
    setState(() {
      selected = savedServers;
    });
  }

  Future<void> _saveSelectedServers() async {
    await Storage.setStringList(
        StorageKeyString.blossomProtocolServers, selected);
  }

  void _toggleEditMode() {
    setState(() {
      isEditMode = !isEditMode;
    });
  }

  void _addToSelected(String url) async {
    if (!selected.contains(url)) {
      setState(() {
        selected.add(url);
      });
      await _saveSelectedServers();
    }
  }

  void _removeFromSelected(String url) async {
    setState(() {
      selected.remove(url);
    });
    await _saveSelectedServers();
  }

  void _showAddCustomDialog() {
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Add Custom Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              controller: urlController,
              placeholder: 'URL',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                if (!(Uri.tryParse(urlController.text)?.hasAbsolutePath ??
                    false)) {
                  EasyLoading.showError('Invalid URL');
                  return;
                }
                _addToSelected(urlController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SettingsList(
        sections: [
          SettingsSection(
            title: Text('Payment Account'),
            tiles: [
              if (selectedIdentity.secp256k1PKHex == selectedPaymentPubkey)
                SettingsTile.navigation(
                    leading: Utils.getRandomAvatar(
                        selectedIdentity.secp256k1PKHex,
                        height: 30,
                        width: 30),
                    title: Text(selectedIdentity.displayName),
                    onPressed: (context) async {
                      List<Identity> identities =
                          await IdentityService.instance.listIdentity();
                      Get.dialog(
                        SimpleDialog(
                          title: const Text('Select a Identity'),
                          children: identities
                              .map((identity) => SimpleDialogOption(
                                    onPressed: () async {
                                      await Storage.setString(
                                          StorageKeyString
                                              .selectedPaymentPubkey,
                                          identity.secp256k1PKHex);
                                      setState(() {
                                        selectedIdentity = identity;
                                        selectedPaymentPubkey =
                                            identity.secp256k1PKHex;
                                      });
                                      Get.back();
                                      EasyLoading.showSuccess(
                                          'Selected Identity: ${identity.displayName}');
                                    },
                                    child: ListTile(
                                      leading: Utils.getRandomAvatar(
                                          identity.secp256k1PKHex,
                                          height: 30,
                                          width: 30),
                                      title: Text(identity.displayName),
                                      selected:
                                          selectedIdentity.secp256k1PKHex ==
                                              identity.secp256k1PKHex,
                                      trailing:
                                          selectedIdentity.secp256k1PKHex ==
                                                  identity.secp256k1PKHex
                                              ? Icon(Icons.check_circle,
                                                  color: Colors.green)
                                              : null,
                                    ),
                                  ))
                              .toList(),
                        ),
                      );
                    }),
              if (selectedIdentity.secp256k1PKHex == selectedPaymentPubkey)
                SettingsTile(
                    title: const Text('Add Payment Private Key'),
                    leading: const Icon(Icons.add),
                    onPressed: (context) async {
                      TextEditingController prikeyController =
                          TextEditingController();
                      String? prikey = await showDialog(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Add a Payment Private Key'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                  'Please enter your private key for payment:'),
                              const Text(
                                  'Private key will be stored in keychain'),
                              const SizedBox(height: 10),
                              CupertinoTextField(
                                placeholder: 'Private Key',
                                maxLines: 3,
                                controller: prikeyController,
                              ),
                            ],
                          ),
                          actions: [
                            CupertinoDialogAction(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            CupertinoDialogAction(
                              onPressed: () {
                                // Handle save private key logic
                                String prikey = prikeyController.text.trim();
                                Navigator.pop(context, prikey);
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                      if (prikey == null) return;
                      try {
                        if (prikey.startsWith('nsec')) {
                          prikey =
                              rust_nostr.getHexPrikeyByBech32(bech32: prikey);
                        }
                        // store in keychain
                        String pubkey =
                            rust_nostr.getHexPubkeyByPrikey(prikey: prikey);
                        await SecureStorage.instance.write(pubkey, prikey);
                        await Storage.setString(
                            StorageKeyString.selectedPaymentPubkey, pubkey);
                        setState(() {
                          selectedPaymentPubkey = pubkey;
                        });
                      } catch (e, s) {
                        String error = Utils.getErrorMessage(e);
                        EasyLoading.showError(error);
                        logger.e('Failed to save payment private key: $error',
                            stackTrace: s);
                      }
                    }),
              if (selectedIdentity.secp256k1PKHex != selectedPaymentPubkey)
                SettingsTile(
                  title: Text('Custom Payment Private Key'),
                  description: Text(
                      'Pubkey: ${rust_nostr.getBech32PubkeyByHex(hex: selectedPaymentPubkey)}'),
                  trailing: IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: () async {
                        Identity identity = Get.find<HomeController>()
                            .allIdentities
                            .values
                            .first;
                        await Storage.setString(
                            StorageKeyString.selectedPaymentPubkey,
                            identity.secp256k1PKHex);
                        setState(() {
                          selectedPaymentPubkey = identity.secp256k1PKHex;
                          selectedIdentity = identity;
                        });
                        EasyLoading.showSuccess(
                            'Payment private key removed, use the identity: ${identity.displayName}');
                      }),
                ),
            ],
          ),
          SettingsSection(
            title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Selected Servers'),
                  TextButton(
                      onPressed: _toggleEditMode,
                      child: Text(isEditMode ? 'Done' : 'Edit'))
                ]),
            tiles: [
              ...selected.map((url) => SettingsTile(
                    title: Text(url),
                    trailing: isEditMode
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red),
                            onPressed: () => _removeFromSelected(url),
                          )
                        : TextButton(
                            onPressed: () {
                              Get.find<MultiWebviewController>()
                                  .launchWebview(content: url);
                            },
                            child: Text('Pay')),
                  )),
              SettingsTile(
                title: const Text('Add Custom Server'),
                leading: const Icon(Icons.add),
                onPressed: (context) => _showAddCustomDialog(),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Recommended Servers'),
            tiles: builtInMedias
                .map((url) => SettingsTile(
                      title: Text(url),
                      trailing: IconButton(
                        icon: Icon(
                          selected.contains(url)
                              ? Icons.check_circle
                              : Icons.add_circle,
                          color: selected.contains(url)
                              ? Colors.green
                              : Colors.blue,
                        ),
                        onPressed: () => _addToSelected(url),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
