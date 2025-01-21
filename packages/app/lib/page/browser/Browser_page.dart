import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/models/browser/browser_favorite.dart';
import 'package:app/page/browser/BrowserBookmarkPage.dart';
import 'package:app/page/browser/BrowserHistoryPage.dart';
import 'package:app/page/browser/BrowserSetting.dart';
import 'package:app/page/browser/WebStorePage.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'Browser_controller.dart';

class BrowserPage extends GetView<BrowserController> {
  const BrowserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: GestureDetector(
            onTap: () {
              Utils.hideKeyboard(Get.context!);
            },
            child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Obx(() => ListView(children: [
                      SizedBox(
                          height: controller.favorites.length < 25
                              ? (150 -
                                  (controller.favorites.length / 5).floor() *
                                      30)
                              : 30),
                      Row(children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 40,
                            maxWidth: Get.width - 72,
                          ),
                          child: Form(
                            key: PageStorageKey(
                                'input:${controller.defaultSearchEngineObx.value}'),
                            child: TextFormField(
                              textInputAction: TextInputAction.go,
                              maxLines: 1,
                              controller: controller.textController,
                              decoration: InputDecoration(
                                labelText: Utils.capitalizeFirstLetter(
                                    controller.defaultSearchEngineObx.value),
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
                                        icon: const Icon(CupertinoIcons.clear),
                                        onPressed: () {
                                          controller.textController.clear();
                                        },
                                      ),
                                    IconButton(
                                      icon: const Icon(CupertinoIcons.search),
                                      onPressed: () async {
                                        if (controller
                                            .textController.text.isEmpty) {
                                          return;
                                        }
                                        controller.lanuchWebview(
                                          content: controller
                                              .textController.text
                                              .trim(),
                                          engine: controller
                                              .defaultSearchEngineObx.value,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              onFieldSubmitted: (value) {
                                controller.lanuchWebview(
                                  engine:
                                      controller.defaultSearchEngineObx.value,
                                  content:
                                      controller.textController.text.trim(),
                                );
                              },
                            ),
                          ),
                        ),
                        IconButton(
                            onPressed: () {
                              Get.to(() => const BrowserSetting());
                            },
                            icon: const Icon(Icons.menu))
                      ]),
                      const SizedBox(height: 32),
                      quickSection(context),
                      const SizedBox(height: 16),
                      functionSection(context),
                      const SizedBox(height: 48)
                    ])))));
  }

  Widget quickSectionItem(Widget icon, String title, String url,
      {required BuildContext context,
      required VoidCallback onTap,
      VoidCallback? onLongPress}) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          icon,
          Text(
            title,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }

  Widget quickSection(BuildContext context) {
    return controller.favorites.isEmpty
        ? Container()
        : Container(
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(10),
                borderRadius: const BorderRadius.all(Radius.circular(8))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8.0,
                  childAspectRatio: 0.7,
                  mainAxisSpacing: 8.0),
              itemCount: controller.favorites.length,
              itemBuilder: (context, index) {
                final site = controller.favorites[index];
                final uri = Uri.parse(site.url);
                String host = uri.host;
                String path = uri.path;
                return quickSectionItem(
                    Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(40),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Utils.getNeworkImageOrDefault(site.favicon,
                            radius: 100, size: 30)),
                    site.title?.isEmpty ?? true ? '$host$path' : site.title!,
                    site.url,
                    onTap: () {
                      controller.lanuchWebview(
                          content: site.url, defaultTitle: site.title);
                    },
                    context: context,
                    onLongPress: () async {
                      if (GetPlatform.isMobile) {
                        HapticFeedback.lightImpact();
                      }
                      BrowserBookmark? bb =
                          await BrowserBookmark.getByUrl(site.url);
                      String title = site.title == null
                          ? site.url
                          : '${site.title} - ${site.url}';
                      showCupertinoModalPopup(
                        context: Get.context!,
                        builder: (BuildContext context) => CupertinoActionSheet(
                          title: Text(title),
                          actions: <CupertinoActionSheetAction>[
                            if (index != 0)
                              CupertinoActionSheetAction(
                                onPressed: () async {
                                  await BrowserFavorite.setPin(site);
                                  EasyLoading.showSuccess('Success');
                                  controller.loadFavorite();
                                  Get.back();
                                },
                                child: const Text('Move to Top'),
                              ),
                            if (bb == null)
                              CupertinoActionSheetAction(
                                child: const Text('Add to bookmark'),
                                onPressed: () async {
                                  await BrowserBookmark.add(
                                      url: site.url,
                                      title: site.title,
                                      favicon: site.favicon);
                                  EasyLoading.showSuccess('Added');
                                  controller.loadFavorite();
                                  Get.back();
                                },
                              ),
                            CupertinoActionSheetAction(
                              isDestructiveAction: true,
                              onPressed: () async {
                                await BrowserFavorite.delete(site.id);
                                EasyLoading.showSuccess('Removed');
                                controller.loadFavorite();
                                Get.back();
                              },
                              child: const Text('Remove'),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Get.back();
                            },
                          ),
                        ),
                      );
                    });
              },
            ));
  }

  Widget functionSection(BuildContext context) {
    var features = [
      {
        'icon': 'assets/images/recommend.png',
        'title': 'Web Store',
        'onTap': () async {
          await Get.to(() => const WebStorePage());
          await Get.find<BrowserController>().loadFavorite();
        }
      },
      {
        'icon': 'assets/images/bookmark.png',
        'title': 'Bookmark',
        'onTap': () {
          Get.to(() => const BrowserBookmarkPage());
          Get.find<BrowserController>().loadFavorite();
        }
      },
      {
        'icon': 'assets/images/history.png',
        'title': 'History',
        'onTap': () {
          Get.to(() => const BrowserHistoryPage());
        }
      }
    ];
    return Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(10),
            borderRadius: const BorderRadius.all(Radius.circular(8))),
        padding: const EdgeInsets.all(16),
        child: Row(
          spacing: 20,
          children: [
            ...features.map((item) {
              return quickSectionItem(
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
