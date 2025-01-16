import 'package:app/controller/home.controller.dart';
import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/page/browser/Browser_controller.dart';
import 'package:app/page/components.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
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
    List<BrowserBookmark> bookmarks = await BrowserBookmark.getAll(limit: 100);
    Set<String> urls = bookmarks.map((e) => e.url).toSet();
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
          title: const Text('Apps'),
        ),
        body: homeController.browserRecommend.entries.isEmpty
            ? pageLoadingSpinKit()
            : SmartRefresher(
                enablePullUp: true,
                enablePullDown: false,
                onLoading: () async {
                  Get.find<HomeController>().loadAppRemoteConfig();
                  refreshController.loadComplete();
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
                                          lineHeight: 1, maxLines: 2),
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
                                                await DBProvider.database
                                                    .writeTxn(() async {
                                                  await DBProvider
                                                      .database.browserBookmarks
                                                      .filter()
                                                      .urlEqualTo(url)
                                                      .deleteAll();
                                                });
                                                setState(() {
                                                  exists = exists..remove(url);
                                                });
                                                Get.find<BrowserController>()
                                                    .loadBookmarks();
                                                EasyLoading.showSuccess(
                                                    'Success');
                                              },
                                              icon: const Icon(Icons.check,
                                                  color: Colors.green))
                                          : IconButton(
                                              onPressed: () async {
                                                await DBProvider.database
                                                    .writeTxn(() async {
                                                  BrowserBookmark bookmark =
                                                      BrowserBookmark(
                                                          url: url,
                                                          title: site['title'],
                                                          favicon: site['img']);
                                                  await DBProvider
                                                      .database.browserBookmarks
                                                      .put(bookmark);
                                                });
                                                setState(() {
                                                  exists = exists..add(url);
                                                });
                                                Get.find<BrowserController>()
                                                    .loadBookmarks();
                                                EasyLoading.showSuccess(
                                                    'Success');
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
