import 'package:keychat/page/components.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart';
import 'package:keychat/utils.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:keychat/service/identity.service.dart';

class CreateAccount extends StatefulWidget {
  const CreateAccount({super.key, this.mnemonic, this.npubs = const []});
  final String? mnemonic;
  final List<String> npubs;

  @override
  _CreateAccountState createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  int selected = -1;
  List<Secp256k1Account> accounts = [];
  late TextEditingController textEditingController;
  late ScrollController scrollController;
  late FocusNode focusNode;

  @override
  void initState() {
    focusNode = FocusNode();
    textEditingController = TextEditingController();
    scrollController = ScrollController();
    scrollController.addListener(() {
      focusNode.unfocus();
    });
    super.initState();
    generateAccount(widget.mnemonic);
  }

  @override
  void dispose() {
    scrollController.dispose();
    focusNode.dispose();
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            const Text('Create ID'),
            Text(
              'Derived from seed phrase',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final name = textEditingController.text.trim();
                    if (name.isEmpty) {
                      EasyLoading.showError('Please input your nickname');
                      return;
                    }
                    if (selected == -1) {
                      EasyLoading.showError('Please select a avatar');
                      return;
                    }
                    try {
                      final isFirstAccount =
                          await IdentityService.instance.count() == 0;

                      final identity = await IdentityService.instance
                          .createIdentity(
                            name: name,
                            account: accounts[selected],
                            index: selected,
                            isFirstAccount: isFirstAccount,
                          );
                      textEditingController.clear();
                      Get.back(result: identity);
                    } catch (e, s) {
                      logger.e(e.toString(), error: e, stackTrace: s);
                      EasyLoading.showToast(e.toString());
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: ListView(
          controller: scrollController,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nick Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Select Your Avatar'),
            ),
            if (accounts.isEmpty)
              pageLoadingSpinKit()
            else
              ListView.builder(
                itemCount: accounts.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return ListTile(
                    onTap: () {
                      if (widget.npubs.contains(accounts[index].pubkeyBech32)) {
                        EasyLoading.showToast('This account already exists');
                        return;
                      }
                      setState(() {
                        selected = index;
                      });
                    },
                    title: Text('#$index'),
                    leading: Utils.getRandomAvatar(accounts[index].pubkey),
                    subtitle: Text(
                      getPublicKeyDisplay(accounts[index].pubkeyBech32, 8),
                    ),
                    selected: selected == index,
                    dense: true,
                    trailing:
                        widget.npubs.contains(accounts[index].pubkeyBech32)
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.grey,
                            size: 24,
                          )
                        : selected == index
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          )
                        : null,
                  );
                },
              ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Future<void> generateAccount(String? mnemonic) async {
    mnemonic ??= await SecureStorage.instance.getOrCreatePhraseWords();

    var list = <Secp256k1Account>[];
    try {
      list = await rust_nostr.importFromPhraseWith(
        phrase: mnemonic,
        offset: 0,
        count: 10,
      );
    } catch (e) {
      final error = Utils.getErrorMessage(e);
      EasyLoading.showError(error);
      if (widget.mnemonic != null) {
        Get.back<void>();
      }
    }

    setState(() {
      accounts = list;
    });
  }
}
