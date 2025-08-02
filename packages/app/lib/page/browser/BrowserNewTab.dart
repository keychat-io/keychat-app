import 'package:app/page/browser/BrowserBookmarkPage.dart';
import 'package:app/page/browser/BrowserHistoryPage.dart';
import 'package:app/page/browser/BrowserSetting.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/page/browser/WebStorePage.dart';
import 'package:app/widgets/browser/quick_section.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class BrowserNewTab extends GetView<MultiWebviewController> {
  const BrowserNewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
            onTap: () {
              Utils.hideKeyboard(Get.context!);
            },
            child: Container(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Obx(() => ListView(children: [
                      SizedBox(height: 16),
                      Form(
                        child: TextFormField(
                          textInputAction: TextInputAction.go,
                          maxLines: 1,
                          controller: controller.textController,
                          decoration: InputDecoration(
                            labelText:
                                'Search ${Utils.capitalizeFirstLetter(controller.defaultSearchEngineObx.value)} or Type a URL',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(100.0)),
                            isDense: true,
                            contentPadding: const EdgeInsets.all(2),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: SvgPicture.asset(
                                'assets/images/logo/${controller.defaultSearchEngineObx.value}.svg',
                                fit: BoxFit.contain,
                                width: 20,
                                height: 20,
                              ),
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (controller.input.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.clear,
                                        size: 20),
                                    onPressed: () {
                                      controller.textController.clear();
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(CupertinoIcons.search,
                                      size: 20),
                                  onPressed: () async {
                                    if (controller
                                        .textController.text.isEmpty) {
                                      return;
                                    }
                                    submitSearchForm(
                                        controller.textController.text.trim());
                                  },
                                ),
                              ],
                            ),
                          ),
                          onFieldSubmitted: submitSearchForm,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (controller.favorites.isNotEmpty) QuickSection(),
                      const SizedBox(height: 16),
                      functionSection(context),
                      const SizedBox(height: 24),
                    ])))));
  }

  void submitSearchForm(value) {
    controller.launchWebview(
      engine: controller.defaultSearchEngineObx.value,
      initUrl: controller.textController.text.trim(),
    );
  }

  Widget functionSection(BuildContext context) {
    var features = [
      {
        'icon': 'assets/images/recommend.png',
        'title': 'Mini App',
        'onTap': () async {
          if (GetPlatform.isDesktop) {
            await Get.bottomSheet(const WebStorePage(),
                isScrollControlled: true, ignoreSafeArea: false);
          } else {
            await Get.to(() => const WebStorePage());
          }
          controller.loadFavorite();
        }
      },
      {
        'icon': 'assets/images/bookmark.png',
        'title': 'Bookmark',
        'onTap': () async {
          if (GetPlatform.isDesktop) {
            await Get.bottomSheet(const BrowserBookmarkPage(),
                isScrollControlled: true, ignoreSafeArea: false);
          } else {
            await Get.to(() => const BrowserBookmarkPage());
          }
          controller.loadFavorite();
        }
      },
      {
        'icon': 'assets/images/history.png',
        'title': 'History',
        'onTap': () async {
          if (GetPlatform.isDesktop) {
            await Get.bottomSheet(const BrowserHistoryPage(),
                isScrollControlled: true, ignoreSafeArea: false);
          } else {
            await Get.to(() => const BrowserHistoryPage());
          }
        }
      },
      {
        'icon': 'assets/images/setting.png',
        'title': 'Setting',
        'onTap': () async {
          if (GetPlatform.isDesktop) {
            await Get.bottomSheet(const BrowserSetting(),
                isScrollControlled: true, ignoreSafeArea: false);
          } else {
            await Get.to(() => const BrowserSetting());
          }
        }
      }
    ];
    return Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(10),
            borderRadius: const BorderRadius.all(Radius.circular(8))),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ...features.map((item) {
              return controller.quickSectionItem(
                  Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Utils.getAssetImage(item['icon'] as String,
                          radius: 0, size: 30)),
                  item['title'] as String,
                  item['title'] as String,
                  onTap: item['onTap'] as VoidCallback,
                  context: context);
            }),
          ],
        ));
  }
}
