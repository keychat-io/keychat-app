import 'package:flutter/material.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/utils.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;

import '../../service/identity.service.dart';
import '../routes.dart';

class CreateAccount extends StatefulWidget {
  final String type;
  const CreateAccount({super.key, required this.type});

  @override
  _CreateAccountState createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  int selected = -1;
  List<Secp256k1Account> accounts = [];
  late TextEditingController textEditingController;
  late FocusNode focusNode;

  @override
  void initState() {
    focusNode = FocusNode();
    textEditingController = TextEditingController();
    super.initState();
    generateAccount();
  }

  @override
  void dispose() {
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
              )
            : null,
        body: SafeArea(
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Nick Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      const Text('Select a avatar'),
                      Expanded(
                        child: GridView.builder(
                            itemCount: accounts.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 0,
                                    mainAxisSpacing: 0),
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                  onTap: () {
                                    Utils.hideKeyboard(context);
                                    setState(() {
                                      selected = index;
                                    });
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: <Widget>[
                                      getRandomAvatar(accounts[index].pubkey,
                                          height: 50, width: 50),
                                      if (index == selected)
                                        CircleAvatar(
                                          backgroundColor:
                                              Colors.black.withOpacity(0.6),
                                          radius: 25,
                                          child: const Icon(Icons.check,
                                              size: 32, color: Colors.green),
                                        ),
                                    ],
                                  ));
                            }),
                      ),
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
                            var identity = await IdentityService()
                                .createIdentity(
                                    name: name, keychain: accounts[selected]);
                            textEditingController.clear();
                            bool isFirstAccount =
                                await IdentityService().count() == 1;
                            if (isFirstAccount) {
                              Get.find<EcashController>()
                                  .setupNewIdentity(identity);
                            }
                            if (Get.arguments == 'create') {
                              EasyLoading.dismiss();
                              await Get.find<HomeController>().loadIdentity();
                              Get.back();
                              return;
                            }
                            Get.offAllNamed(Routes.root,
                                arguments: isFirstAccount);
                          } catch (e, s) {
                            logger.e(e.toString(), error: e, stackTrace: s);
                            EasyLoading.showToast(e.toString());
                          } finally {
                            EasyLoading.dismiss();
                          }
                        },
                        child: const Text(
                          'Confirm',
                        ),
                      ),
                    ]))));
  }

  void generateAccount() async {
    List<Secp256k1Account> list = [];
    for (var i = 0; i < 8; i++) {
      var account = await rustNostr.generateFromMnemonic();
      list.add(account);
    }
    setState(() {
      accounts = list;
    });
  }
}
