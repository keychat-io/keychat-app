import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/page/browser/BrowserBookmarkPage.dart';
import 'package:app/page/browser/BrowserHistoryPage.dart';
import 'package:app/page/browser/Recommends.dart';
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
            child: Obx(() => Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: ListView(children: [
                  SizedBox(
                      height: 240 - controller.enableSearchEngine.length * 30),
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
                              controller.favorites();
                              Get.back();
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ));
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
          await Get.to(() => const Recommends());
          await Get.find<BrowserController>().loadFavorite();
        }
      },
      {
        'icon': 'assets/images/bookmark.png',
        'title': 'Bookmark',
        'onTap': () {
          Get.to(() => const BrowserBookmarkPage());
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
