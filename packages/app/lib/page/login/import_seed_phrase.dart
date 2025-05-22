import 'package:app/page/login/CreateAccount.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class ImportSeedPhrase extends StatefulWidget {
  const ImportSeedPhrase({super.key});

  @override
  _ImportSeedPhrase createState() => _ImportSeedPhrase();
}

class _ImportSeedPhrase extends State<ImportSeedPhrase> {
  late TextEditingController _privateKeyController;
  late FocusNode focusNode2;

  @override
  void initState() {
    _privateKeyController = TextEditingController();
    focusNode2 = FocusNode();
    super.initState();
  }

  @override
  void dispose() {
    focusNode2.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            centerTitle: true, title: const Text("Import from Seed Phrase")),
        body: SafeArea(
          child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Form(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                              const SizedBox(height: 16),
                              TextField(
                                  controller: _privateKeyController,
                                  textInputAction: TextInputAction.done,
                                  minLines: 1,
                                  maxLines: 6,
                                  focusNode: focusNode2,
                                  decoration: InputDecoration(
                                      labelText: 'Seed Phrase',
                                      hintText: '12 or 24 words',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                          icon: const Icon(Icons.paste),
                                          onPressed: () async {
                                            final clipboardData =
                                                await Clipboard.getData(
                                                    'text/plain');
                                            if (clipboardData != null) {
                                              final pastedText =
                                                  clipboardData.text;
                                              if (pastedText != null &&
                                                  pastedText != '') {
                                                _privateKeyController.text =
                                                    pastedText;
                                                _privateKeyController
                                                        .selection =
                                                    TextSelection.fromPosition(
                                                        TextPosition(
                                                            offset:
                                                                _privateKeyController
                                                                    .text
                                                                    .length));
                                              }
                                            }
                                          }))),
                            ]))),
                    Center(
                        child: Container(
                            constraints: BoxConstraints(maxWidth: 400),
                            width: double.infinity,
                            child: FilledButton(
                              child: const Text('Next'),
                              onPressed: () async {
                                String input =
                                    _privateKeyController.text.trim();

                                if (input.isEmpty) {
                                  EasyLoading.showError(
                                      'Please enter your seed phrase (12 or 24 words)');
                                  return;
                                }
                                List<String> words = input.split(' ');
                                if (words.length != 24 && words.length != 12) {
                                  EasyLoading.showError(
                                      'Seed phrase must be exactly 24 words');
                                  return;
                                }
                                var res = await Get.to(
                                    () => CreateAccount(mnemonic: input));
                                Get.back(result: res);
                              },
                            )))
                  ])),
        ));
  }
}
