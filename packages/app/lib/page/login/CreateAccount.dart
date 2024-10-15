import 'package:app/page/components.dart';
import 'package:app/page/login/import_nsec.dart';
import 'package:flutter/material.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/utils.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import '../../service/identity.service.dart';
import '../routes.dart';

class CreateAccount extends StatefulWidget {
  final String type;
  final String? mnemonic;
  final List<String> npubs;
  const CreateAccount(
      {super.key, required this.type, this.mnemonic, this.npubs = const []});

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
        appBar: widget.type != "tab"
            ? AppBar(
                title: const Text('Create ID'),
                bottom: const PreferredSize(
                    preferredSize: Size.fromHeight(0),
                    child: Text('Derived from seed phrase')),
                actions: Get.previousRoute == '/login'
                    ? []
                    : [
                        TextButton(
                            onPressed: () {
                              Get.off(() => const ImportNsec());
                            },
                            child: const Text('Import Nsec'))
                      ])
            : null,
        floatingActionButton: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () async {
                      String name = textEditingController.text.trim();
                      if (name.isEmpty) {
                        EasyLoading.showError("Please input your nickname");
                        return;
                      }
                      if (selected == -1) {
                        EasyLoading.showError("Please select a avatar");
                        return;
                      }
                      try {
                        EasyLoading.show(status: 'Loading...');
                        bool isFirstAccount =
                            await IdentityService().count() == 0;

                        await IdentityService().createIdentity(
                            name: name,
                            account: accounts[selected],
                            index: selected,
                            isFirstAccount: isFirstAccount);
                        textEditingController.clear();

                        EasyLoading.dismiss();
                        if (Get.arguments == 'create') {
                          await Get.find<HomeController>().loadIdentity();
                          Get.back();
                          return;
                        }
                        Get.offAllNamed(Routes.root, arguments: isFirstAccount);
                      } catch (e, s) {
                        logger.e(e.toString(), error: e, stackTrace: s);
                        EasyLoading.showToast(e.toString());
                      }
                    },
                    child: const Text('Confirm'),
                  )
                ])),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: SafeArea(
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                child: ListView(controller: scrollController, children: [
                  TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nick Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Your Avatar'),
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
                                  EasyLoading.showToast(
                                      'This account already exists');
                                  return;
                                }
                                setState(() {
                                  selected = index;
                                });
                              },
                              title: Text('#$index'),
                              leading: getRandomAvatar(accounts[index].pubkey,
                                  height: 50, width: 50),
                              subtitle: Text(getPublicKeyDisplay(
                                  accounts[index].pubkeyBech32, 8)),
                              selected: selected == index,
                              trailing: widget.npubs
                                      .contains(accounts[index].pubkeyBech32)
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.grey, size: 30)
                                  : selected == index
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.green, size: 30)
                                      : null,
                            );
                          }),
                  const SizedBox(height: 100)
                ]))));
  }

  void generateAccount(String? mnemonic) async {
    if (mnemonic == null) {
      var account = await rust_nostr.generateFromMnemonic();
      mnemonic = account.mnemonic!;
    }

    List<Secp256k1Account> list = await rust_nostr.importFromPhraseWith(
        phrase: mnemonic, offset: 0, count: 10);

    setState(() {
      accounts = list;
    });
  }
}
