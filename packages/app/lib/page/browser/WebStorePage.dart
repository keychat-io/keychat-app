import 'package:app/controller/home.controller.dart';
import 'package:app/models/browser/browser_favorite.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/page/components.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class WebStorePage extends StatefulWidget {
  const WebStorePage({super.key});

  @override
  _WebStorePageState createState() => _WebStorePageState();
}

class _WebStorePageState extends State<WebStorePage> {
  late HomeController homeController;
  Set<String> exists = {};
  late RefreshController refreshController;
  late MultiWebviewController controller;
  @override
  void initState() {
    controller = Get.find<MultiWebviewController>();
    refreshController = RefreshController();
    homeController = Get.find<HomeController>();
    init();
    super.initState();
  }

  init() async {
    if (homeController.recommendWebstore.isEmpty) {
      await homeController.loadAppRemoteConfig();
    }
    List<BrowserFavorite> list = controller.favorites;
    Set<String> urls = list.map((e) => e.url).toSet();
    setState(() {
      exists = urls;
    });
  }

  @override
  void dispose() {
    refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Web Store'),
        ),
        body: Obx(() => homeController.recommendWebstore.entries.isEmpty
            ? pageLoadingSpinKit()
            : SmartRefresher(
                enablePullDown: true,
                onRefresh: () async {
                  await Get.find<HomeController>().loadAppRemoteConfig();
                  refreshController.refreshCompleted();
                },
                controller: refreshController,
                child: ListView.builder(
                    itemCount: homeController.recommendWebstore.entries.length,
                    itemBuilder: (context, index) {
                      final entry = homeController.recommendWebstore.entries
                          .elementAt(index);
                      return Padding(
                          padding: const EdgeInsets.only(
                              left: 16, right: 16, bottom: 16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    Utils.capitalizeFirstLetter(
                                        entry.key.toString()),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: entry.value.length,
                                  itemBuilder: (context, index) {
                                    final site = entry.value[index];
                                    String url = site['url1'] ?? site['url2'];
                                    return ListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.all(0),
                                      leading: Utils.getNeworkImageOrDefault(
                                          site['img']),
                                      title: Text(site['title'],
                                          overflow: TextOverflow.fade,
                                          maxLines: 1),
                                      subtitle: textSmallGray(
                                          context, site['description'],
                                          maxLines: 1),
                                      onTap: () {
                                        Get.find<MultiWebviewController>()
                                            .lanuchWebview(
                                                content: url,
                                                defaultTitle: site['title']);
                                      },
                                      trailing: exists.contains(url)
                                          ? IconButton(
                                              onPressed: () async {
                                                await BrowserFavorite
                                                    .deleteByUrl(url);
                                                setState(() {
                                                  exists = exists..remove(url);
                                                });

                                                EasyLoading.showSuccess(
                                                    'Removed from favorites');
                                              },
                                              icon: const Icon(Icons.check,
                                                  color: Colors.green))
                                          : IconButton(
                                              onPressed: () async {
                                                await BrowserFavorite.add(
                                                    url: url,
                                                    title: site['title'],
                                                    favicon: site['img']);
                                                setState(() {
                                                  exists = exists..add(url);
                                                });
                                                EasyLoading.showSuccess(
                                                    'Added to favorites');
                                              },
                                              icon: Icon(
                                                Icons.add,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              )),
                                    );
                                  },
                                ),
                              ]));
                    }))));
  }
}
