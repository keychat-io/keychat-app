import 'package:app/page/login/login.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gif/gif.dart';
import 'package:onboarding/onboarding.dart';

import '../../service/storage.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

var list = [
  {
    'icon': 'assets/images/around-the-world.gif',
    'title': 'Based on Nostr Procotol',
    'desc':
        'A simple, open protocol that enables a truly censorship-resistant and global social network.'
  },
  {
    'icon': 'assets/images/safe-box.gif',
    'title': 'Local Storage',
    'desc':
        'Data is stored locally and your friend relationships are not leaked.'
  },
  {
    'icon': 'assets/images/rocket.gif',
    'title': 'Signal Protocol',
    'desc':
        'KeyChat uses the Double Ratchet Algorithm of Signal Procotol for message encryption and the Nostr protocol for message delivery.'
  },
  {
    'icon': 'assets/images/social-media.gif',
    'title': 'Rotating receiving and sending addresses',
    'desc':
        'Random key for sending messages, and each round the receiving key is rotated to prevent leakage of message metadata.'
  },
];

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late Material materialButton;
  late GifController controller;
  late int index;
  final ScrollController scrollController = ScrollController();
  @override
  void initState() {
    controller = GifController(vsync: this);
    super.initState();
    materialButton = _skipButton();
    index = 0;
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Material _skipButton({void Function(int)? setIndex}) {
    return Material(
      child: InkWell(
          borderRadius: defaultSkipButtonBorderRadius,
          onTap: () {
            if (setIndex != null) {
              index = list.length - 1;
              setIndex(list.length - 1);
            }
          },
          child: OutlinedButton(
              onPressed: () {
                Storage.setInt(StorageKeyString.onboarding, 1);
                Get.to(() => const Login());
              },
              child: const Text('Skip'))),
    );
  }

  Material get _signupButton {
    return Material(
        child: FilledButton(
            onPressed: () {
              Storage.setInt(StorageKeyString.onboarding, 1);

              Get.to(() => const Login());
            },
            child: const Text('Start')));
  }

  @override
  Widget build(BuildContext context) {
    Color background = Theme.of(context).colorScheme.surface;
    return Scaffold(
      body: Onboarding(
        pages: list
            .map(
              (e) => PageModel(
                widget: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    border: Border.all(
                      width: 0.0,
                      color: background,
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      children: [
                        Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 45.0,
                              vertical: 90.0,
                            ),
                            child: Gif(
                              controller: controller,
                              autostart: Autostart.loop,
                              image: AssetImage(e['icon']!),
                            )),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 45.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              e['title']!,
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 45.0, vertical: 10.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              e['desc']!,
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
        onPageChange: (int pageIndex) {
          index = pageIndex;
        },
        startPageIndex: 0,
        footerBuilder: (context, dragDistance, pagesLength, setIndex) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              border: Border.all(
                width: 0.0,
                color: background,
              ),
            ),
            child: ColoredBox(
              color: background,
              child: Padding(
                padding: const EdgeInsets.all(45.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomIndicator(
                      netDragPercent: dragDistance,
                      pagesLength: pagesLength,
                      indicator: Indicator(
                        indicatorDesign: IndicatorDesign.line(
                          lineDesign: LineDesign(
                            lineType: DesignType.line_uniform,
                          ),
                        ),
                      ),
                    ),
                    index == pagesLength - 1
                        ? _signupButton
                        : _skipButton(setIndex: setIndex)
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
