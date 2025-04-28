import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/models/browser/browser_favorite.dart';
import 'package:app/page/browser/BrowserBookmarkPage.dart';
import 'package:app/page/browser/BrowserHistoryPage.dart';
import 'package:app/page/browser/BrowserSetting.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/page/browser/WebStorePage.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class BrowserHome extends GetView<MultiWebviewController> {
  const BrowserHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
            onTap: () {
              Utils.hideKeyboard(Get.context!);
            },
            child: SafeArea(
                child: Container(
                    padding: const EdgeInsets.only(left: 16, right: 16),
                    child: Obx(() => ListView(children: [
                          SizedBox(height: 32),
                          Form(
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
                                        submitSearchForm(controller
                                            .textController.text
                                            .trim());
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              onFieldSubmitted: submitSearchForm,
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (controller.favorites.isNotEmpty)
                            quickSection(context),
                          const SizedBox(height: 16),
                          functionSection(context),
                          const SizedBox(height: 48)
                        ]))))));
  }

  void submitSearchForm(value) {
    controller.lanuchWebview(
      engine: controller.defaultSearchEngineObx.value,
      content: controller.textController.text.trim(),
    );
  }

  Widget quickSectionItem(Widget icon, String title, String url,
      {required BuildContext context,
      required VoidCallback onTap,
      VoidCallback? onLongPress,
      Future Function(TapDownDetails e)? onSecondaryTapDown}) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          icon,
          Text(title,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis)
        ],
      ),
    );
  }

  Widget quickSection(BuildContext context) {
    int crossAxisCount = 4;
    double spacing = 8.0;
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
    } else if (screenWidth < 900) {
      crossAxisCount = 5;
    } else if (screenWidth < 1200) {
      crossAxisCount = 8;
    } else {
      crossAxisCount = 10;
    }

    return Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(10),
            borderRadius: const BorderRadius.all(Radius.circular(8))),
        padding: const EdgeInsets.all(8),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing),
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
                      color:
                          Theme.of(context).colorScheme.onSurface.withAlpha(40),
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
                onSecondaryTapDown: (e) async {
                  if (!GetPlatform.isDesktop) {
                    return;
                  }
                  final RenderBox overlay = Overlay.of(context)
                      .context
                      .findRenderObject() as RenderBox;
                  final position = RelativeRect.fromRect(
                      Rect.fromPoints(
                        e.globalPosition,
                        e.globalPosition,
                      ),
                      Offset.zero & overlay.size);

                  final site = controller.favorites[index];
                  BrowserBookmark? bb =
                      await BrowserBookmark.getByUrl(site.url);

                  showMenu(
                    context: Get.context!,
                    position: position,
                    items: [
                      if (index != 0)
                        PopupMenuItem(
                          child: const Text('Move to Top'),
                          onTap: () async {
                            await BrowserFavorite.setPin(site);
                            EasyLoading.showSuccess('Success');
                            controller.loadFavorite();
                          },
                        ),
                      if (bb == null)
                        PopupMenuItem(
                          child: const Text('Add to bookmark'),
                          onTap: () async {
                            await BrowserBookmark.add(
                                url: site.url,
                                title: site.title,
                                favicon: site.favicon);
                            EasyLoading.showSuccess('Added');
                            controller.loadFavorite();
                          },
                        ),
                      PopupMenuItem(
                        child: const Text('Remove',
                            style: TextStyle(color: Colors.red)),
                        onTap: () async {
                          await BrowserFavorite.delete(site.id);
                          EasyLoading.showSuccess('Removed');
                          controller.loadFavorite();
                        },
                      ),
                    ],
                  );
                },
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
        'title': 'Mini APP',
        'onTap': () async {
          if (GetPlatform.isDesktop) {
            await Get.bottomSheet(const WebStorePage());
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
            await Get.bottomSheet(const BrowserBookmarkPage());
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
            await Get.bottomSheet(const BrowserHistoryPage());
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
            await Get.bottomSheet(const BrowserSetting());
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
