import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/service/signal_chat.service.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class AddBotPage extends StatefulWidget {
  const AddBotPage({super.key});

  @override
  State<AddBotPage> createState() => _AddBotPageState();
}

class _AddBotPageState extends State<AddBotPage> {
  late TextEditingController _nameController;
  late TextEditingController _pubkeyController;
  late Identity selectedIdentity;
  EncryptMode encryptMode = EncryptMode.nip04;
  HomeController homeController = Get.find<HomeController>();

  @override
  void initState() {
    selectedIdentity = homeController.getSelectedIdentity();
    _nameController = TextEditingController();
    _pubkeyController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pubkeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Add Bot'),
        actions: [
          Utils.selectIdentityIconButton(
            identity: selectedIdentity,
            onChanged: (identity) {
              if (identity == null) return;
              setState(() {
                selectedIdentity = identity;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        textInputAction: TextInputAction.next,
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Bot Name',
                          border: OutlineInputBorder(),
                          hintText: 'Enter bot name',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        textInputAction: TextInputAction.done,
                        maxLines: 4,
                        minLines: 1,
                        controller: _pubkeyController,
                        decoration: const InputDecoration(
                          labelText: 'Bot Pubkey (hex or npub)',
                          border: OutlineInputBorder(),
                          hintText: 'Enter bot pubkey',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Encrypt Mode',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildEncryptModeSelector(),
                    ],
                  ),
                ),
              ),
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _createBot,
                    child: const Text('Confirm'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEncryptModeSelector() {
    return RadioGroup<EncryptMode>(
      groupValue: encryptMode,
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          encryptMode = value;
        });
      },
      child: Column(
        children: [
          ListTile(
            title: Text(
              'NIP17',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Text(
              'Gift-wrapped direct message with better privacy',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            leading: const Radio<EncryptMode>(
              value: EncryptMode.nip17,
            ),
            selected: encryptMode == EncryptMode.nip17,
            selectedTileColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.1),
            onTap: () {
              setState(() {
                encryptMode = EncryptMode.nip17;
              });
            },
          ),

          ListTile(
            title: Text(
              'NIP04',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Text(
              'Basic encrypted direct message',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            leading: const Radio<EncryptMode>(
              value: EncryptMode.nip04,
            ),
            selected: encryptMode == EncryptMode.nip04,
            selectedTileColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.1),
            onTap: () {
              setState(() {
                encryptMode = EncryptMode.nip04;
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _createBot() async {
    final name = _nameController.text.trim();
    final pubkeyInput = _pubkeyController.text.trim();

    if (name.isEmpty) {
      EasyLoading.showToast('Please enter bot name');
      return;
    }

    if (pubkeyInput.isEmpty) {
      EasyLoading.showToast('Please enter bot pubkey');
      return;
    }

    String hexPubkey;
    try {
      if (pubkeyInput.startsWith('npub') && pubkeyInput.length == 63) {
        hexPubkey = rust_nostr.getHexPubkeyByBech32(bech32: pubkeyInput);
      } else if (pubkeyInput.length == 64) {
        hexPubkey = pubkeyInput;
        // Validate hex pubkey by converting to npub and back
        rust_nostr.getBech32PubkeyByHex(hex: hexPubkey);
      } else {
        EasyLoading.showError('Invalid pubkey format');
        return;
      }
    } catch (e) {
      logger.e('Invalid pubkey: $e');
      EasyLoading.showError('Invalid pubkey format');
      return;
    }

    // Check if it's self pubkey
    if (hexPubkey == selectedIdentity.secp256k1PKHex) {
      EasyLoading.showError('Cannot add yourself as a bot');
      return;
    }

    // Check if it's another identity's pubkey
    for (final iden in homeController.allIdentities.values) {
      if (iden.secp256k1PKHex == hexPubkey) {
        EasyLoading.showError("Cannot add other identity's pubkey as a bot");
        return;
      }
    }

    try {
      EasyLoading.show(status: 'Creating...');

      // Check if room already exists
      final existRoom = await RoomService.instance.getRoomByIdentity(
        hexPubkey,
        selectedIdentity.id,
      );

      if (existRoom != null) {
        EasyLoading.dismiss();
        EasyLoading.showToast('Bot room already exists');
        await Utils.offAndToNamedRoom(existRoom);
        return;
      }

      // Create bot room
      final room = await RoomService.instance.getOrCreateRoom(
        hexPubkey,
        selectedIdentity.secp256k1PKHex,
        RoomStatus.enabled,
        contactName: name,
        type: RoomType.freebot,
        identity: selectedIdentity,
        encryptMode: encryptMode,
      );

      // Add contact
      await ContactService.instance.addContactToFriend(
        pubkey: hexPubkey,
        identityId: selectedIdentity.id,
        name: name,
      );

      EasyLoading.dismiss();
      EasyLoading.showSuccess('Bot added successfully');

      // Navigate to chat page
      await Utils.offAndToNamedRoom(room);
      homeController.loadIdentityRoomList(selectedIdentity.id);
    } catch (e, s) {
      EasyLoading.dismiss();
      logger.e('Failed to create bot room', error: e, stackTrace: s);
      EasyLoading.showError('Failed to add bot: ${Utils.getErrorMessage(e)}');
    }
  }
}
