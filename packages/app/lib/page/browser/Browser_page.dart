import 'package:app/page/browser/BrowserHistoryPage.dart';
import 'package:app/page/browser/BrowserSetting.dart';
import 'package:app/page/common.dart';
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
    return Scaffold(
        appBar: AppBar(
          toolbarHeight: 40,
          actions: [
            // Obx(() => GestureDetector(
            //       child: getRandomAvatar(
            //           controller.identity.value.secp256k1PKHex,
            //           height: 30,
            //           width: 30),
            //       onTap: () {
            //         Get.toNamed(Routes.settingMe,
            //             arguments: controller.identity.value);
            //       },
            //     )),
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                Get.to(() => const BrowserSetting());
              },
            )
          ],
        ),
        body: GestureDetector(
            onTap: () {
              Utils.hideKeyboard(Get.context!);
            },
            child: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                    child: Obx(() => ListView(children: [
                          ...controller.enableSearchEngine.map((engine) =>
                              Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 12, top: 4),
                                  child: Form(
                                    key: PageStorageKey('input:$engine'),
                                    child: TextFormField(
                                      textInputAction: TextInputAction.go,
                                      maxLines: 1,
                                      controller: controller.textController,
                                      decoration: InputDecoration(
                                          labelText:
                                              Utils.capitalizeFirstLetter(
                                                  engine),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(100.0)),
                                          prefixIcon: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: SvgPicture.asset(
                                                'assets/images/$engine.svg',
                                                fit: BoxFit.contain,
                                                width: 16,
                                                height: 16),
                                          ),
                                          suffixIcon: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (controller.input.isNotEmpty)
                                                IconButton(
                                                  icon: const Icon(
                                                      CupertinoIcons.clear),
                                                  onPressed: () {
                                                    controller.textController
                                                        .clear();
                                                  },
                                                ),
                                              IconButton(
                                                icon: const Icon(
                                                    CupertinoIcons.search),
                                                onPressed: () async {
                                                  if (controller.textController
                                                      .text.isEmpty) {
                                                    return;
                                                  }
                                                  controller.lanuchWebview(
                                                      content: controller
                                                          .textController.text
                                                          .trim(),
                                                      engine: engine);
                                                },
                                              ),
                                            ],
                                          )),
                                      onFieldSubmitted: (value) {
                                        controller.lanuchWebview(
                                            engine: engine,
                                            content: controller
                                                .textController.text
                                                .trim());
                                      },
                                    ),
                                  ))),
                          if (controller.histories.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('History',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                IconButton(
                                  icon:
                                      const Icon(CupertinoIcons.right_chevron),
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
                              mainAxisSpacing: 8.0,
                              childAspectRatio: 2.5,
                            ),
                            itemCount: controller.histories.length,
                            itemBuilder: (context, index) {
                              final site = controller.histories[index];
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .dividerColor
                                          .withAlpha(50)),
                                  borderRadius: BorderRadius.circular(8.0),
                                  color: Theme.of(context).cardColor,
                                ),
                                child: ListTile(
                                  title: site.title != null
                                      ? Text(site.title!,
                                          overflow: TextOverflow.ellipsis)
                                      : null,
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      textSmallGray(context, site.url),
                                      textSmallGray(
                                          context,
                                          getFormatTimeForMessage(
                                              site.createdAt)),
                                    ],
                                  ),
                                  dense: true,
                                  onTap: () {
                                    controller.lanuchWebview(
                                        engine: BrowserEngine.google.name,
                                        content: site.url,
                                        defaultTitle: site.title);
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text('Recommended',
                                  style:
                                      Theme.of(context).textTheme.titleMedium)),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8.0,
                              mainAxisSpacing: 8.0,
                              childAspectRatio: 3,
                            ),
                            itemCount: controller.recommendedUrls.length,
                            itemBuilder: (context, index) {
                              final site = controller.recommendedUrls[index];
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .dividerColor
                                          .withAlpha(50)),
                                  borderRadius: BorderRadius.circular(8.0),
                                  color: Theme.of(context).cardColor,
                                ),
                                child: ListTile(
                                  title: Text(site['title']),
                                  subtitle: textSmallGray(context, site['url']),
                                  dense: true,
                                  onTap: () {
                                    controller.lanuchWebview(
                                        engine: BrowserEngine.google.name,
                                        content: site['url'],
                                        defaultTitle: site['title']);
                                  },
                                ),
                              );
                            },
                          ),
                        ]))))));
  }
}
