import 'package:app/models/browser/browser_bookmark.dart';
import 'package:app/page/browser/Browser_controller.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class BrowserBookmarkPage extends StatefulWidget {
  const BrowserBookmarkPage({super.key});

  @override
  _BrowserBookmarkPageState createState() => _BrowserBookmarkPageState();
}

class _BrowserBookmarkPageState extends State<BrowserBookmarkPage> {
  List<BrowserBookmark> urls = [];
  late RefreshController refreshController;
  @override
  void initState() {
    refreshController = RefreshController();
    loadData(limit: 20, offset: 0);
    super.initState();
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
              await loadData(limit: 20, offset: urls.length);
              refreshController.loadComplete();
            },
            controller: refreshController,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: urls.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const Divider(
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final site = urls[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 1.0, horizontal: 16.0),
                  leading: Utils.getNeworkImage(site.favicon, radius: 100),
                  minVerticalPadding: 0,
                  minTileHeight: 56,
                  title: site.title == null
                      ? null
                      : Text(site.title!, maxLines: 1),
                  subtitle: Text(site.url,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        icon: site.isPin
                            ? Icon(
                                CupertinoIcons.pin_fill,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : const Icon(CupertinoIcons.pin),
                        onPressed: () async {
                          site.isPin = !site.isPin;
                          await BrowserBookmark.update(site);
                          urls.clear();
                          loadData(limit: 20, offset: 0);
                          Get.find<BrowserController>().loadBookmarks();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          BrowserBookmark.delete(site.id);
                          setState(() {
                            urls.removeAt(index);
                          });
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
    urls.addAll(list);
    setState(() {
      urls = [...urls];
    });
  }
}
