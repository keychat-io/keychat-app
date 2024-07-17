import 'package:app/global.dart';
import 'package:flutter/material.dart';

class OnboardingPage2Detail extends StatelessWidget {
  const OnboardingPage2Detail({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            'About Keychat',
          ),
        ),
        body: SafeArea(
            child: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, bottom: 60, top: 16),
            child: Text(
              KeychatGlobal.keychatIntro2,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        )));
  }
}
