import 'package:app/global.dart';
import 'package:app/page/login/CreateAccount.dart';
import 'package:app/page/login/OnboardingPage2Detail.dart';
import 'package:app/page/setting/more_setting.dart';
import 'package:app/service/secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
                  const SizedBox(height: 50),
                  Text('Keychat',
                      style: Theme.of(context).textTheme.titleLarge),
                  ...KeychatGlobal.keychatIntros.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(e,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.4)))),
                  TextButton(
                      onPressed: () =>
                          Get.to(() => const OnboardingPage2Detail()),
                      child: const Text("More >")),
                ],
              )),
              Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                        onPressed: () async {
                          await SecureStorage.instance.clearAll();
                          Get.to(() => const CreateAccount(type: "init"));
                        },
                        child: const Text("Create ID",
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 16.0),
                    OutlinedButton(
                        onPressed: () async {
                          // Identity? res =
                          //     await Get.to(() => const ImportNsec());
                          // if (res != null) {
                          //   Get.offAndToNamed(Routes.root);
                          // }
                          const MoreSetting().enableImportDB(context);
                        },
                        child: const Text("Import Data",
                            style: TextStyle(fontWeight: FontWeight.bold)))
                  ])
            ])));
  }
}
