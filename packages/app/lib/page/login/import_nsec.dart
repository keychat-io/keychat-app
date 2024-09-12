import 'package:app/controller/home.controller.dart';
import 'package:app/models/models.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import '../../service/identity.service.dart';

class ImportNsec extends StatefulWidget {
  const ImportNsec({super.key});

  @override
  _ImportNsec createState() => _ImportNsec();
}

class _ImportNsec extends State<ImportNsec> {
  late TextEditingController nameController;
  late TextEditingController _privateKeyController;
  late FocusNode focusNode2;

  @override
  void initState() {
    _privateKeyController = TextEditingController();
    nameController = TextEditingController();
    focusNode2 = FocusNode();
    super.initState();
  }

  @override
  void dispose() {
    focusNode2.dispose();
    nameController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(centerTitle: true, title: const Text("Import ID")),
        body: SafeArea(
          child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Column(children: [
                Form(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                          TextField(
                              controller: nameController,
                              textInputAction: TextInputAction.next,
                              autofocus: true,
                              decoration: const InputDecoration(
                                  labelText: 'My Nickname',
                                  hintText: 'Show to friends',
                                  border: OutlineInputBorder())),
                          const SizedBox(height: 16),
                          TextField(
                              controller: _privateKeyController,
                              textInputAction: TextInputAction.done,
                              minLines: 1,
                              maxLines: 2,
                              focusNode: focusNode2,
                              decoration: InputDecoration(
                                  labelText: 'Nsec / Hex Private Key',
                                  hintText: 'Nsec / Hex Private Key',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                      icon: const Icon(Icons.paste),
                                      onPressed: () async {
                                        final clipboardData =
                                            await Clipboard.getData(
                                                'text/plain');
                                        if (clipboardData != null) {
                                          final pastedText = clipboardData.text;
                                          if (pastedText != null &&
                                              pastedText != '') {
                                            _privateKeyController.text =
                                                pastedText;
                                            _privateKeyController.selection =
                                                TextSelection.fromPosition(
                                                    TextPosition(
                                                        offset:
                                                            _privateKeyController
                                                                .text.length));
                                          }
                                        }
                                      }))),
                        ]))),
                FilledButton(
                  style: ButtonStyle(
                      minimumSize: WidgetStateProperty.all(
                          const Size(double.infinity, 44))),
                  child: const Text('Confirm'),
                  onPressed: () async {
                    String name = nameController.text.trim();
                    String input = _privateKeyController.text.trim();
                    if (name.isEmpty) {
                      EasyLoading.showError('Please enter a nickname');
                      return;
                    }
                    if (input.isEmpty) {
                      EasyLoading.showError(
                          'Please enter a Nsec / Hex Private Key');
                      return;
                    }
                    try {
                      if (input.startsWith('nsec')) {
                        input = rust_nostr.getHexPrikeyByBech32(bech32: input);
                      }
                      String hexPubkey =
                          rust_nostr.getHexPubkeyByPrikey(prikey: input);
                      Identity? exist = await IdentityService()
                          .getIdentityByNostrPubkey(hexPubkey);
                      if (exist != null) {
                        EasyLoading.showError('This prikey already exists');
                        return;
                      }
                      var newIdentity = await IdentityService()
                          .createIdentityByPrikey(
                              name: name, prikey: input, hexPubkey: hexPubkey);
                      Get.find<HomeController>().identities.length == 1;

                      EasyLoading.showSuccess('Import successfully');
                      Get.back(result: newIdentity);
                    } catch (e, s) {
                      String msg = Utils.getErrorMessage(e);
                      logger.e('Import failed', error: e, stackTrace: s);
                      EasyLoading.showToast('Import failed: $msg');
                    }
                  },
                )
              ])),
        ));
  }
}
