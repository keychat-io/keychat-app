import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:keychat/constants/legal_links.dart';
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
                    Text(
                      'Keychat is the super app for Bitcoiners.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Autonomous IDs, Bitcoin ecash wallet, secure chat, and rich Mini Apps — all in Keychat.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      spacing: 8,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Chip(
                          label: const Text('Autonomy'),
                          avatar: SvgPicture.asset(
                            'assets/images/wallet.svg',
                            width: 16,
                            height: 16,
                          ),
                        ),
                        Chip(
                          label: const Text('Security'),
                          avatar: SvgPicture.asset(
                            'assets/images/security.svg',
                            width: 16,
                            height: 16,
                          ),
                        ),
                        Chip(
                          label: const Text('Richness'),
                          avatar: Image.asset(
                            'assets/images/recommend.png',
                            width: 16,
                            height: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await launchUrl(Uri.parse(LegalLinks.privacyPolicy));
                        },
                        child: const Text('Privacy Policy'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          await launchUrl(
                            Uri.parse(LegalLinks.termsConditions),
                          );
                        },
                        child: const Text('Terms & Conditions'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () async {
                          await launchUrl(Uri.parse('https://www.keychat.io'));
                        },
                        child: const Text('More'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
