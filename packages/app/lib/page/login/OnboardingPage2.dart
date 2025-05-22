import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/utils.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('About Keychat'),
          centerTitle: true,
        ),
        body: SafeArea(
            child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                  child: Column(
                crossAxisAlignment: GetPlatform.isDesktop
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Keychat is the super app for Bitcoiners.',
                      style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 16),
                  Text(
                      'Autonomous IDs, Bitcoin ecash wallet, secure chat, and rich Mini Apps — all in Keychat.'),
                  SizedBox(height: 16),
                  Row(
                    spacing: 8,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Chip(
                          label: Text('Autonomy'),
                          avatar: SvgPicture.asset('assets/images/wallet.svg',
                              width: 16, height: 16)),
                      Chip(
                          label: Text('Security'),
                          avatar: SvgPicture.asset('assets/images/security.svg',
                              width: 16, height: 16)),
                      Chip(
                          label: Text('Richness'),
                          avatar: Image.asset('assets/images/recommend.png',
                              width: 16, height: 16)),
                    ],
                  )
                ],
              )),
              Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 400),
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () {
                        launchUrl(Uri.parse('https://www.keychat.io'));
                      },
                      child: const Text("More")),
                ),
              ),
            ],
          ),
        )));
  }
}
