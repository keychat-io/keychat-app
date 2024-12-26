import 'package:app/controller/home.controller.dart';
import 'package:app/page/browser/BrowserBookmarkPage.dart';
import 'package:app/page/browser/BrowserHistoryPage.dart';
import 'package:app/page/components.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'Browser_controller.dart';

class BrowserPage extends GetView<BrowserController> {
  const BrowserPage({super.key});

  @override
  Widget build(BuildContext context) {
    HomeController homeController = Get.find<HomeController>();
    return Scaffold(
        body: GestureDetector(
            onTap: () {
              Utils.hideKeyboard(Get.context!);
            },
            child: SafeArea(
                child: Obx(() => ListView(children: [
                      if (controller.enableSearchEngine.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount:
                              controller.enableSearchEngine.toList().length,
                          itemBuilder: (context, index) {
                            final engine =
                                controller.enableSearchEngine.toList()[index];
                            return Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 8, top: 8, left: 16, right: 16),
                              child: Form(
                                key: PageStorageKey('input:$engine'),
                                child: TextFormField(
                                  textInputAction: TextInputAction.go,
                                  maxLines: 1,
                                  controller: controller.textController,
                                  decoration: InputDecoration(
                                    labelText:
                                        Utils.capitalizeFirstLetter(engine),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(100.0)),
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
                                            icon: const Icon(
                                                CupertinoIcons.clear),
                                            onPressed: () {
                                              controller.textController.clear();
                                            },
                                          ),
                                        IconButton(
                                          icon:
                                              const Icon(CupertinoIcons.search),
                                          onPressed: () async {
                                            if (controller
                                                .textController.text.isEmpty) {
                                              return;
                                            }
                                            controller.lanuchWebview(
                                              content: controller
                                                  .textController.text
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
                                      content:
                                          controller.textController.text.trim(),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      if (controller.histories.isNotEmpty)
                        Column(children: [
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: Text('History',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium)),
                              IconButton(
                                icon: const Icon(CupertinoIcons.right_chevron,
                                    size: 18),
                                onPressed: () {
                                  Get.to(() => const BrowserHistoryPage());
                                },
                              ),
                            ],
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8.0,
                              childAspectRatio: 4,
                            ),
                            itemCount: controller.histories.length,
                            itemBuilder: (context, index) {
                              final site = controller.histories[index];
                              return ListTile(
                                minTileHeight: 40,
                                minVerticalPadding: 0,
                                leading: Utils.getNeworkImage(site.favicon),
                                title: Text(site.title ?? site.url,
                                    overflow: TextOverflow.clip, maxLines: 1),
                                subtitle: textSmallGray(context, site.url),
                                dense: true,
                                onTap: () {
                                  controller.lanuchWebview(
                                      engine: BrowserEngine.google.name,
                                      content: site.url,
                                      defaultTitle: site.title);
                                },
                              );
                            },
                          )
                        ]),
                      if (controller.bookmarks.isNotEmpty)
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: Text('Bookmark',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(height: 1))),
                                IconButton(
                                  icon: const Icon(CupertinoIcons.right_chevron,
                                      size: 18),
                                  onPressed: () {
                                    Get.to(() => const BrowserBookmarkPage());
                                  },
                                ),
                              ],
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(0),
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8.0,
                                childAspectRatio: 4,
                              ),
                              itemCount: controller.bookmarks.length,
                              itemBuilder: (context, index) {
                                final site = controller.bookmarks[index];
                                return ListTile(
                                  minTileHeight: 40,
                                  minVerticalPadding: 0,
                                  leading: Utils.getNeworkImage(site.favicon),
                                  title: site.title != null
                                      ? Text(site.title!,
                                          overflow: TextOverflow.fade,
                                          maxLines: 1)
                                      : null,
                                  subtitle: textSmallGray(context, site.url),
                                  dense: true,
                                  onTap: () {
                                    controller.lanuchWebview(
                                        engine: BrowserEngine.google.name,
                                        content: site.url,
                                        defaultTitle: site.title);
                                  },
                                );
                              },
                            )
                          ],
                        ),
                      Obx(() => ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount:
                              homeController.browserRecommend.entries.length,
                          itemBuilder: (context, index) {
                            final entry = homeController
                                .browserRecommend.entries
                                .elementAt(index);
                            return Padding(
                                padding: const EdgeInsets.only(
                                    left: 16, right: 16, bottom: 16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          Utils.capitalizeFirstLetter(
                                              entry.key.toString()),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                crossAxisSpacing: 16.0,
                                                mainAxisSpacing: 8.0,
                                                childAspectRatio: 3.4),
                                        itemCount: entry.value.length,
                                        itemBuilder: (context, index) {
                                          final site = entry.value[index];
                                          return ListTile(
                                            dense: true,
                                            contentPadding:
                                                const EdgeInsets.all(0),
                                            leading: Utils.getNeworkImage(
                                                site['img']),
                                            title: Text(site['title'],
                                                overflow: TextOverflow.fade,
                                                maxLines: 1),
                                            subtitle: textSmallGray(
                                                context, site['description'],
                                                lineHeight: 1, maxLines: 2),
                                            onTap: () {
                                              controller.lanuchWebview(
                                                  engine:
                                                      BrowserEngine.google.name,
                                                  content: site['url1'] ??
                                                      site['url2'],
                                                  defaultTitle: site['title']);
                                            },
                                          );
                                        },
                                      ),
                                    ]));
                          })),
                      const SizedBox(height: 50)
                    ])))));
  }
}
