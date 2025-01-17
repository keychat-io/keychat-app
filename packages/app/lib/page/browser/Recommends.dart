import 'package:app/controller/home.controller.dart';
import 'package:app/models/browser/browser_favorite.dart';
import 'package:app/page/browser/Browser_controller.dart';
import 'package:app/page/components.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class Recommends extends StatefulWidget {
  const Recommends({super.key});

  @override
  _RecommendsState createState() => _RecommendsState();
}

class _RecommendsState extends State<Recommends> {
  late HomeController homeController;
  Set<String> exists = {};
  late RefreshController refreshController;
  @override
  void initState() {
    refreshController = RefreshController();
    homeController = Get.find<HomeController>();
    init();
    super.initState();
  }

  init() async {
    List<BrowserFavorite> list = Get.find<BrowserController>().favorites;
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
        body: homeController.browserRecommend.entries.isEmpty
            ? pageLoadingSpinKit()
            : SmartRefresher(
                enablePullDown: true,
                onRefresh: () async {
                  Get.find<HomeController>().loadAppRemoteConfig();
                  refreshController.refreshCompleted();
                },
                controller: refreshController,
                child: Obx(() => ListView.builder(
                    itemCount: homeController.browserRecommend.entries.length,
                    itemBuilder: (context, index) {
                      final entry = homeController.browserRecommend.entries
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
                                        Get.find<BrowserController>()
                                            .lanuchWebview(
                                                engine:
                                                    BrowserEngine.google.name,
                                                content: url,
                                                defaultTitle: site['title']);
                                      },
                                      trailing: exists.contains(url)
                                          ? IconButton(
                                              onPressed: () async {
                                                await BrowserFavorite
                                                    .deleteAll();
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
