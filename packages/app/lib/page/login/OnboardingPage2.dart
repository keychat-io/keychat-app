import 'package:app/global.dart';
import 'package:app/page/login/OnboardingPage2Detail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('About Keychat'),
        ),
        body: SafeArea(
            child: Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                  child: Column(
                children: KeychatGlobal.keychatIntros
                    .map((e) => Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(e,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      height: 1.4,
                                    ))))
                    .toList(),
              )),
              OutlinedButton(
                  onPressed: () => Get.to(() => const OnboardingPage2Detail()),
                  child: const Text(
                    "More >",
                  )),
              const SizedBox(
                height: 10,
              ),
              TextButton(
                  onPressed: () {
                    launchUrl(Uri.parse('https://www.keychat.io'));
                  },
                  child: const Text('HomePage')),
            ],
          ),
        )));
  }
}
