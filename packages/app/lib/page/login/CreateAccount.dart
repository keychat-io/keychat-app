import 'package:app/page/components.dart';
import 'package:flutter/material.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart';
import 'package:app/utils.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import '../../service/identity.service.dart';

class CreateAccount extends StatefulWidget {
  final String? mnemonic;
  final List<String> npubs;
  const CreateAccount({super.key, this.mnemonic, this.npubs = const []});

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
          title: Column(children: [
            const Text('Create ID'),
            Text('Derived from seed phrase',
                style: Theme.of(context).textTheme.bodySmall)
          ]),
        ),
        floatingActionButton: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: Container(
                          constraints: BoxConstraints(maxWidth: 400),
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              String name = textEditingController.text.trim();
                              if (name.isEmpty) {
                                EasyLoading.showError(
                                    "Please input your nickname");
                                return;
                              }
                              if (selected == -1) {
                                EasyLoading.showError("Please select a avatar");
                                return;
                              }
                              try {
                                bool isFirstAccount =
                                    await IdentityService.instance.count() == 0;

                                var identity = await IdentityService.instance
                                    .createIdentity(
                                        name: name,
                                        account: accounts[selected],
                                        index: selected,
                                        isFirstAccount: isFirstAccount);
                                textEditingController.clear();
                                Get.back(result: identity);
                              } catch (e, s) {
                                logger.e(e.toString(), error: e, stackTrace: s);
                                EasyLoading.showToast(e.toString());
                              }
                            },
                            child: const Text('Confirm'),
                          )))
                ])),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: SafeArea(
            child: ListView(controller: scrollController, children: [
          Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nick Name',
                  border: OutlineInputBorder(),
                ),
              )),
          const SizedBox(height: 8),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Select Your Avatar')),
          accounts.isEmpty
              ? pageLoadingSpinKit()
              : ListView.builder(
                  itemCount: accounts.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return ListTile(
                      onTap: () {
                        if (widget.npubs
                            .contains(accounts[index].pubkeyBech32)) {
                          EasyLoading.showToast('This account already exists');
                          return;
                        }
                        setState(() {
                          selected = index;
                        });
                      },
                      title: Text('#$index'),
                      leading: Utils.getRandomAvatar(accounts[index].pubkey,
                          height: 40, width: 40),
                      subtitle: Text(
                          getPublicKeyDisplay(accounts[index].pubkeyBech32, 8)),
                      selected: selected == index,
                      dense: true,
                      trailing:
                          widget.npubs.contains(accounts[index].pubkeyBech32)
                              ? const Icon(Icons.check_circle,
                                  color: Colors.grey, size: 24)
                              : selected == index
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green, size: 24)
                                  : null,
                    );
                  }),
          const SizedBox(height: 100)
        ])));
  }

  void generateAccount(String? mnemonic) async {
    if (mnemonic == null) {
      var account = await rust_nostr.generateFromMnemonic();
      mnemonic = account.mnemonic!;
    }

    List<Secp256k1Account> list = [];
    try {
      list = await rust_nostr.importFromPhraseWith(
          phrase: mnemonic, offset: 0, count: 10);
    } catch (e) {
      String error = Utils.getErrorMessage(e);
      EasyLoading.showError(error);
      if (widget.mnemonic != null) {
        Get.back();
      }
    }

    setState(() {
      accounts = list;
    });
  }
}
