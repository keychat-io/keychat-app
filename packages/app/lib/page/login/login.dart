import 'package:app/global.dart';
import 'package:app/models/identity.dart';
import 'package:app/page/login/CreateAccount.dart';
import 'package:app/page/login/OnboardingPage2Detail.dart';
import 'package:app/page/login/import_nsec.dart';
import 'package:app/page/login/import_seed_phrase.dart';
import 'package:app/page/routes.dart';
import 'package:app/page/setting/more_chat_setting.dart';
import 'package:app/service/SignerService.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(context) {
    return SafeArea(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Expanded(
                  child: Column(
                children: <Widget>[
                  Text('Keychat',
                      style: Theme.of(context).textTheme.titleLarge),
                  ...KeychatGlobal.keychatIntros.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(e,
                          style: Theme.of(context).textTheme.bodyLarge))),
                  TextButton(
                      onPressed: () =>
                          Get.to(() => const OnboardingPage2Detail()),
                      child: const Text("More >")),
                ],
              )),
              Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    FilledButton(
                        onPressed: () async {
                          try {
                            await SecureStorage.instance.clearAll();
                            Get.to(() => const CreateAccount(type: "init"));
                          } catch (e, s) {
                            EasyLoading.showError(e.toString());
                            logger.e(e.toString(), stackTrace: s);
                          }
                        },
                        child: const Text("Create ID")),
                    OutlinedButton(
                        onPressed: () async {
                          Get.bottomSheet(getRecoverPage());
                        },
                        child: const Text("Recover ID")),
                    if (GetPlatform.isAndroid)
                      OutlinedButton.icon(
                          icon: SvgPicture.asset(
                            'assets/images/logo/amber.svg',
                            fit: BoxFit.contain,
                            width: 20,
                            height: 20,
                          ),
                          onPressed: handleAmberLogin,
                          label: const Text("Login with Amber App"))
                  ])
            ])));
  }

  Widget getRecoverPage() {
    return SettingsList(platform: DevicePlatform.iOS, sections: [
      SettingsSection(title: const Text('Recover ID'), tiles: [
        SettingsTile.navigation(
          leading: const Icon(Icons.local_activity),
          title: const Text("From Seed Phrase"),
          onPressed: (context) async {
            await Get.to(() => const ImportSeedPhrase());
          },
        ),
        SettingsTile.navigation(
          leading: const Icon(Icons.vpn_key),
          title: const Text("From Nesc"),
          onPressed: (context) async {
            Identity? res = await Get.to(() => const ImportNsec());
            if (res != null) {
              Get.offAllNamed(Routes.root);
            }
          },
        ),
      ]),
      SettingsSection(tiles: [
        SettingsTile.navigation(
          leading: const Icon(Icons.file_open),
          title: const Text("From Backup File"),
          onPressed: (context) {
            const MoreChatSetting().enableImportDB(context);
          },
        )
      ]),
    ]);
  }

  void handleAmberLogin() async {
    String? pubkey = await SignerService.instance.getPublicKey();
    if (pubkey == null) {
      EasyLoading.showError("Not Authorized");
      return;
    }

    TextEditingController controller = TextEditingController();
    var focusNode = FocusNode();
    Future submitAmberLogin([String? value]) async {
      String name = controller.text.trim();
      if (name.isEmpty) {
        EasyLoading.showError("Username is required");
        return;
      }
      Get.back();
      EasyLoading.show(status: 'Loading...');

      await IdentityService.instance.createIdentityByAmberPubkey(
        name: name,
        pubkey: pubkey,
      );

      EasyLoading.dismiss();

      Get.offAllNamed(Routes.root, arguments: true);
    }

    Get.dialog<String>(
      CupertinoAlertDialog(
        title: const Text('Login with Amber App'),
        content: Form(
          child: Column(
            children: [
              Text(pubkey),
              const SizedBox(height: 8),
              TextFormField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Nickname', border: OutlineInputBorder()),
                onFieldSubmitted: submitAmberLogin,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: submitAmberLogin,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
