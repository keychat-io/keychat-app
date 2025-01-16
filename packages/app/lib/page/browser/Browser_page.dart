import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/page/browser/BrowserBookmarkPage.dart';
import 'package:app/page/browser/BrowserHistoryPage.dart';
import 'package:app/page/browser/Recommends.dart';
import 'package:app/page/components.dart';
import 'package:app/utils.dart';
import 'package:auto_size_text_plus/auto_size_text_plus.dart';
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
            child: Obx(() => Padding(
                padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 240 - controller.enableSearchEngine.length * 30,
                    bottom: 16),
                child: ListView(children: [
                  ...controller.enableSearchEngine.toList().reversed.map(
                    (engine) {
                      return Container(
                        width: Get.width,
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Form(
                          key: PageStorageKey('input:$engine'),
                          child: TextFormField(
                            textInputAction: TextInputAction.go,
                            maxLines: 1,
                            controller: controller.textController,
                            decoration: InputDecoration(
                              labelText: Utils.capitalizeFirstLetter(engine),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(100.0)),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: SvgPicture.asset(
                                  'assets/images/logo/$engine.svg',
                                  fit: BoxFit.contain,
                                  width: 16,
                                  height: 16,
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
                                        content: controller.textController.text
                                            .trim(),
                                        engine: engine,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            onFieldSubmitted: (value) {
                              controller.lanuchWebview(
                                engine: engine,
                                content: controller.textController.text.trim(),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  quickSection(),
                  const SizedBox(height: 50)
                ])))));
  }

  Widget myBookmarkSection() {
    return controller.bookmarks.isEmpty
        ? Container()
        : Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('Bookmark',
                          style: Theme.of(Get.context!)
                              .textTheme
                              .titleMedium
                              ?.copyWith(height: 1))),
                  IconButton(
                    icon: const Icon(CupertinoIcons.right_chevron, size: 18),
                    onPressed: () {
                      Get.to(() => const BrowserBookmarkPage());
                    },
                  ),
                ],
              ),
              Container(
                  width: Get.width - 32,
                  decoration: BoxDecoration(
                      color: Theme.of(Get.context!)
                          .colorScheme
                          .onSurface
                          .withAlpha(10),
                      borderRadius: BorderRadius.circular(8)),
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.bookmarks.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final site = controller.bookmarks[index];
                      String host = Uri.parse(site.url).host;
                      return GestureDetector(
                        child: Container(
                            width: 80,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                Utils.getNeworkImageOrDefault(site.favicon,
                                    radius: 100),
                                const SizedBox(height: 8),
                                textSmallGray(
                                  context,
                                  site.title ?? host,
                                  textAlign: TextAlign.center,
                                  lineHeight: 1,
                                  maxLines: 2,
                                  overflow: TextOverflow.clip,
                                )
                              ],
                            )),
                        onTap: () {
                          controller.lanuchWebview(
                              engine: BrowserEngine.google.name,
                              content: site.url,
                              defaultTitle: site.title);
                        },
                      );
                    },
                  ))
            ],
          );
  }

  Widget historySection() {
    return controller.histories.isEmpty
        ? Container()
        : Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('History',
                          style: Theme.of(Get.context!)
                              .textTheme
                              .titleMedium
                              ?.copyWith(height: 1))),
                  IconButton(
                    icon: const Icon(CupertinoIcons.right_chevron, size: 18),
                    onPressed: () {
                      Get.to(() => const BrowserHistoryPage());
                    },
                  ),
                ],
              ),
              Container(
                  width: Get.width - 32,
                  decoration: BoxDecoration(
                      color: Theme.of(Get.context!)
                          .colorScheme
                          .onSurface
                          .withAlpha(10),
                      borderRadius: BorderRadius.circular(8)),
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.histories.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final site = controller.histories[index];
                      final uri = Uri.parse(site.url);
                      String host = uri.host;
                      String path = uri.path;
                      return GestureDetector(
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              Utils.getNeworkImageOrDefault(site.favicon,
                                  radius: 100),
                              const SizedBox(height: 8),
                              textSmallGray(
                                context,
                                site.title?.isEmpty ?? true
                                    ? '$host$path'
                                    : site.title!,
                                lineHeight: 1,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.clip,
                              )
                            ],
                          ),
                        ),
                        onTap: () {
                          controller.lanuchWebview(
                              engine: BrowserEngine.google.name,
                              content: site.url,
                              defaultTitle: site.title);
                        },
                      );
                    },
                  ))
            ],
          );
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
          AutoSizeText(
            title,
            maxLines: 1,
            maxFontSize: 14,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }

  Widget quickSection() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 0.8),
      itemCount: controller.bookmarks.length + 3,
      itemBuilder: (context, index) {
        if (index == controller.bookmarks.length) {
          return quickSectionItem(
              Utils.getAssetImage('assets/images/recommend.png', radius: 100),
              'Web Store',
              'Web Store', onTap: () async {
            Get.bottomSheet(const Recommends(),
                isScrollControlled: true,
                ignoreSafeArea: false,
                enterBottomSheetDuration: Duration.zero);
          }, context: context);
        }
        if (index == controller.bookmarks.length + 2) {
          return quickSectionItem(
              Utils.getAssetImage('assets/images/history.png', radius: 100),
              'History',
              'History', onTap: () {
            Get.to(() => const BrowserHistoryPage());
          }, context: context);
        }

        if (index == controller.bookmarks.length + 1) {
          return quickSectionItem(
              Utils.getAssetImage('assets/images/bookmark.png', radius: 100),
              'Bookmark',
              'Bookmark', onTap: () {
            Get.to(() => const BrowserBookmarkPage());
          }, context: context);
        }
        final site = controller.bookmarks[index];
        final uri = Uri.parse(site.url);
        String host = uri.host;
        String path = uri.path;
        return quickSectionItem(
            Utils.getNeworkImageOrDefault(site.favicon, radius: 100),
            site.title?.isEmpty ?? true ? '$host$path' : site.title!,
            site.url,
            onTap: () {
              controller.lanuchWebview(
                  engine: BrowserEngine.google.name,
                  content: site.url,
                  defaultTitle: site.title);
            },
            context: context,
            onLongPress: () {
              if (GetPlatform.isMobile) {
                HapticFeedback.lightImpact();
              }
              Get.dialog(CupertinoAlertDialog(
                title: const Text('Delete Bookmark'),
                content: Text('Are you sure to delete ${site.title}?'),
                actions: <Widget>[
                  CupertinoDialogAction(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Get.back();
                    },
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    onPressed: () async {
                      await BrowserBookmark.delete(site.id);
                      EasyLoading.showSuccess('Deleted');
                      controller.loadBookmarks();
                      Get.back();
                    },
                    child: const Text('Delete'),
                  ),
                ],
              ));
            });
      },
    );
  }
}
