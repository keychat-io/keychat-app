import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/models/browser/browser_favorite.dart';
import 'package:app/page/browser/BookmarkEdit.dart';
import 'package:app/page/browser/Browser_controller.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class BrowserBookmarkPage extends StatefulWidget {
  const BrowserBookmarkPage({super.key});

  @override
  _BrowserBookmarkPageState createState() => _BrowserBookmarkPageState();
}

class _BrowserBookmarkPageState extends State<BrowserBookmarkPage> {
  List<BrowserBookmark> bookmarks = [];
  Set<String> exists = {};
  late RefreshController refreshController;
  @override
  void initState() {
    refreshController = RefreshController();
    init();
    super.initState();
  }

  init() async {
    List<BrowserFavorite> list = await BrowserFavorite.getAll();
    Set<String> urls = list.map((e) => e.url).toSet();
    setState(() {
      exists = urls;
    });
    bookmarks.clear();
    loadData(limit: 20, offset: 0);
  }

  @override
  void dispose() {
    refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Bookmark')),
        body: SmartRefresher(
            enablePullUp: true,
            enablePullDown: false,
            onLoading: () async {
              await loadData(limit: 20, offset: bookmarks.length);
              refreshController.loadComplete();
            },
            controller: refreshController,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: bookmarks.length,
              itemBuilder: (context, index) {
                final site = bookmarks[index];
                String url = site.url;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 1.0, horizontal: 16.0),
                  leading: Utils.getNetworkImage(site.favicon, radius: 100),
                  minVerticalPadding: 0,
                  minTileHeight: 56,
                  title: site.title == null
                      ? null
                      : Text(site.title!, maxLines: 1),
                  subtitle: Text(site.url,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Wrap(
                    children: [
                      exists.contains(url)
                          ? IconButton(
                              onPressed: () async {
                                await BrowserFavorite.deleteByUrl(url);
                                setState(() {
                                  exists = exists..remove(url);
                                });

                                EasyLoading.showSuccess(
                                    'Remved from Favorites');
                              },
                              icon:
                                  const Icon(Icons.check, color: Colors.green))
                          : IconButton(
                              onPressed: () async {
                                await BrowserFavorite.add(
                                    url: url,
                                    title: site.title,
                                    favicon: site.favicon);
                                setState(() {
                                  exists = exists..add(url);
                                });
                                EasyLoading.showSuccess('Added to Favorites');
                              },
                              icon: const Icon(Icons.add)),
                      IconButton(
                        icon: const Icon(Icons.more_horiz),
                        onPressed: () async {
                          await Get.to(() => BookmarkEdit(model: site));
                          init();
                        },
                      )
                    ],
                  ),
                  onTap: () {
                    Get.find<BrowserController>().lanuchWebview(
                        content: site.url, defaultTitle: site.title);
                  },
                );
              },
            )));
  }

  Future loadData({required int limit, required int offset}) async {
    var list = await BrowserBookmark.getAll(limit: limit, offset: offset);
    bookmarks.addAll(list);
    setState(() {
      bookmarks = [...bookmarks];
    });
  }
}
