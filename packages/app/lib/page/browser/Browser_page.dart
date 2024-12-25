import 'package:app/controller/home.controller.dart';
import 'package:app/models/identity.dart';
import 'package:app/page/browser/BrowserBookmarkPage.dart';
import 'package:app/page/browser/BrowserHistoryPage.dart';
import 'package:app/page/browser/BrowserSetting.dart';
import 'package:app/page/common.dart';
import 'package:app/page/components.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'Browser_controller.dart';

class BrowserPage extends GetView<BrowserController> {
  const BrowserPage({super.key});

  @override
  Widget build(BuildContext context) {
    HomeController homeController = Get.find<HomeController>();
    return Scaffold(
        appBar: AppBar(
          toolbarHeight: 40,
          actions: [
            GestureDetector(
                onTap: () async {
                  List<Identity> identities =
                      await IdentityService.instance.getIdentityList();
                  Get.bottomSheet(
                      SettingsList(platform: DevicePlatform.iOS, sections: [
                    SettingsSection(
                        title: const Text('Select a Identity for Browser'),
                        tiles: identities
                            .map((iden) => SettingsTile(
                                leading: getRandomAvatar(iden.secp256k1PKHex,
                                    height: 30, width: 30),
                                value: iden.id == controller.identity.value.id
                                    ? const Icon(
                                        CupertinoIcons.check_mark_circled,
                                        color: Colors.green)
                                    : null,
                                title: Text(iden.displayName),
                                description: Text(iden.npub),
                                onPressed: (context) async {
                                  controller.setDefaultIdentity(iden);
                                  EasyLoading.showSuccess(
                                      'Switched to ${iden.displayName}');
                                  Get.back();
                                }))
                            .toList())
                  ]));
                },
                child: Obx(() => getRandomAvatar(
                    controller.identity.value.secp256k1PKHex,
                    height: 30,
                    width: 30))),
            IconButton(
              icon: const Icon(CupertinoIcons.settings),
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
                child: Obx(() => ListView(children: [
                      ...controller.enableSearchEngine.map((engine) => Padding(
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
                                        height: 16),
                                  ),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (controller.input.isNotEmpty)
                                        IconButton(
                                          icon:
                                              const Icon(CupertinoIcons.clear),
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
                                              engine: engine);
                                        },
                                      ),
                                    ],
                                  )),
                              onFieldSubmitted: (value) {
                                controller.lanuchWebview(
                                    engine: engine,
                                    content:
                                        controller.textController.text.trim());
                              },
                            ),
                          ))),
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
                                icon: const Icon(CupertinoIcons.right_chevron),
                                onPressed: () {
                                  Get.to(() => const BrowserHistoryPage());
                                },
                              ),
                            ],
                          ),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: GridView.builder(
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
                              ))
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
                                            .titleMedium)),
                                IconButton(
                                  icon:
                                      const Icon(CupertinoIcons.right_chevron),
                                  onPressed: () {
                                    Get.to(() => const BrowserBookmarkPage());
                                  },
                                ),
                              ],
                            ),
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8.0,
                                    mainAxisSpacing: 1,
                                    childAspectRatio: 3,
                                  ),
                                  itemCount: controller.bookmarks.length,
                                  itemBuilder: (context, index) {
                                    final site = controller.bookmarks[index];
                                    return Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Theme.of(context)
                                                .dividerColor
                                                .withAlpha(50)),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        color: Theme.of(context).cardColor,
                                      ),
                                      child: ListTile(
                                        title: site.title != null
                                            ? Text(site.title!,
                                                overflow: TextOverflow.ellipsis)
                                            : null,
                                        subtitle:
                                            textSmallGray(context, site.url),
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
                                ))
                          ],
                        ),
                      Obx(() => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: homeController.browserRecommend.entries
                              .map((entry) {
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                      padding: const EdgeInsets.only(
                                          top: 16, left: 16, right: 16),
                                      child: Text(
                                          Utils.capitalizeFirstLetter(
                                              entry.key.toString()),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium)),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 8.0,
                                      mainAxisSpacing: 8.0,
                                      childAspectRatio: 3.6,
                                    ),
                                    itemCount: entry.value.length,
                                    itemBuilder: (context, index) {
                                      final site = entry.value[index];
                                      return ListTile(
                                        contentPadding: const EdgeInsets.only(
                                            left: 16, right: 4, bottom: 4),
                                        leading: site['img'] != null
                                            ? (site['img']
                                                    .toString()
                                                    .endsWith('svg')
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                    child: SvgPicture.network(
                                                        site['img'],
                                                        width: 40,
                                                        height: 40,
                                                        placeholderBuilder:
                                                            (BuildContext context) =>
                                                                const Icon(Icons
                                                                    .image)))
                                                : CachedNetworkImage(
                                                    imageUrl: site['img'],
                                                    width: 40,
                                                    height: 40,
                                                    imageBuilder: (context,
                                                            imageProvider) =>
                                                        Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8.0),
                                                            image: DecorationImage(
                                                                image:
                                                                    imageProvider,
                                                                fit: BoxFit
                                                                    .cover,
                                                                colorFilter:
                                                                    const ColorFilter
                                                                        .mode(
                                                                        Colors
                                                                            .white,
                                                                        BlendMode
                                                                            .colorBurn)),
                                                          ),
                                                        ),
                                                    placeholder: (context, url) =>
                                                        const Icon(Icons.image),
                                                    errorWidget: (context, url,
                                                            error) =>
                                                        const Icon(Icons.image)))
                                            : null,
                                        title: Text(site['title'],
                                            overflow: TextOverflow.fade,
                                            maxLines: 1),
                                        subtitle: textSmallGray(
                                            context, site['description'],
                                            lineHeight: 1, maxLines: 2),
                                        onTap: () {
                                          controller.lanuchWebview(
                                              engine: BrowserEngine.google.name,
                                              content:
                                                  site['url1'] ?? site['url2'],
                                              defaultTitle: site['title']);
                                        },
                                      );
                                    },
                                  ),
                                ]);
                          }).toList())),
                      const SizedBox(height: 50)
                    ])))));
  }
}
