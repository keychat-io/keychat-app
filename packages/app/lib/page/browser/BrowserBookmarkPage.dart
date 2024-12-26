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
            enablePullDown: true,
            onLoading: () async {
              await loadData(limit: 20, offset: urls.length);
              refreshController.loadComplete();
            },
            controller: refreshController,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: urls.length,
              itemBuilder: (context, index) {
                final site = urls[index];
                return ListTile(
                  minTileHeight: 4,
                  leading: Utils.getNeworkImage(site.favicon),
                  title: site.title == null ? null : Text(site.title!),
                  subtitle: Text(site.url,
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  dense: true,
                  onLongPress: () {
                    Get.dialog(CupertinoAlertDialog(
                      title: const Text('Delete Bookmark'),
                      content: const Text(
                          'Are you sure you want to delete this bookmark?'),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () {
                            Get.back();
                          },
                          child: const Text('Cancel'),
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          onPressed: () async {
                            await BrowserBookmark.delete(site.id);
                            setState(() {
                              urls.removeAt(index);
                            });
                            Get.back();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ));
                  },
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
