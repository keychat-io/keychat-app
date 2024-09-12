import 'package:app/page/components.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import '../../service/identity.service.dart';

class ImportKey extends StatefulWidget {
  const ImportKey({super.key});

  @override
  _ImportKey createState() => _ImportKey();
}

class _ImportKey extends State<ImportKey> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  FocusNode focusNode2 = FocusNode();
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
        appBar: AppBar(
          centerTitle: true,
          title: const Text("Import ID"),
        ),
        body: SafeArea(
          child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
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
                            border: OutlineInputBorder(),
                          )),
                      const SizedBox(
                        height: 16,
                      ),
                      TextField(
                        controller: _privateKeyController,
                        textInputAction: TextInputAction.done,
                        minLines: 2,
                        maxLines: 4,
                        focusNode: focusNode2,
                        decoration: InputDecoration(
                            labelText: 'Seed phrase (12 words)',
                            hintText: '12 words',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.paste),
                              onPressed: () async {
                                final clipboardData =
                                    await Clipboard.getData('text/plain');
                                if (clipboardData != null) {
                                  final pastedText = clipboardData.text;
                                  if (pastedText != null && pastedText != '') {
                                    _privateKeyController.text = pastedText;
                                    _privateKeyController.selection =
                                        TextSelection.fromPosition(TextPosition(
                                            offset: _privateKeyController
                                                .text.length));
                                  }
                                }
                              },
                            )),
                      ),
                      textSmallGray(
                          context, 'Use a space to separate each word.'),
                      textSmallGray(context,
                          'Deriving private and public keys based on bitcoin bip32 and bip39.',
                          overflow: TextOverflow.clip),
                    ],
                  )),
                ),
                FilledButton(
                  style: ButtonStyle(
                      minimumSize: WidgetStateProperty.all(
                          const Size(double.infinity, 44))),
                  child: const Text(
                    'Confirm',
                  ),
                  onPressed: () async {
                    String name = nameController.text.trim();
                    String input = _privateKeyController.text.trim();
                    List<String> mnemonics = input.split(' ');
                    if (mnemonics.length != 12) {
                      EasyLoading.showError('Error seed phrase format.');
                      return;
                    }
                    try {
                      var kc = await rust_nostr.importFromPhrase(phrase: input);
                      bool isFirstAccount =
                          await IdentityService().count() == 0;
                      await IdentityService().createIdentity(
                          name: name,
                          account: kc,
                          index: 0,
                          isFirstAccount: isFirstAccount);

                      EasyLoading.showSuccess('Import successfully');
                      Get.back();
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
