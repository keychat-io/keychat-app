import 'package:app/models/browser/browser_history.dart';
import 'package:app/page/browser/Browser_controller.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class BrowserHistoryPage extends StatefulWidget {
  const BrowserHistoryPage({super.key});

  @override
  _BrowserHistoryPageState createState() => _BrowserHistoryPageState();
}

class _BrowserHistoryPageState extends State<BrowserHistoryPage> {
  Map<String, List<BrowserHistory>> groupedHistory = {};
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
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  Get.dialog(CupertinoAlertDialog(
                      title: const Text('Clear History'),
                      content: const Text(
                          'Are you sure you want to clear your browsing history?'),
                      actions: [
                        CupertinoDialogAction(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Get.back();
                            }),
                        CupertinoDialogAction(
                            child: const Text('Clear'),
                            onPressed: () async {
                              await BrowserHistory.deleteAll();
                              setState(() {
                                groupedHistory.clear();
                              });
                              Get.back();
                            })
                      ]));
                })
          ],
        ),
        body: SmartRefresher(
            enablePullUp: true,
            enablePullDown: false,
            onLoading: () async {
              int amount = groupedHistory.values.fold<int>(0,
                  (previousValue, element) => previousValue + element.length);
              await loadData(limit: 20, offset: amount);
              refreshController.loadComplete();
            },
            controller: refreshController,
            child: ListView.builder(
              itemCount: groupedHistory.length,
              itemBuilder: (context, index) {
                final dateKey = groupedHistory.keys.elementAt(index);
                final date = DateTime.parse(dateKey);
                final urls = groupedHistory[dateKey]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 16),
                      child: Text(
                          formatTime(date.millisecondsSinceEpoch, 'yyyy-MM-dd'),
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: urls.length,
                      itemBuilder: (context, index) {
                        final site = urls[index];
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          leading: Utils.getNetworkImage(site.favicon),
                          title: (site.title == null || site.title!.isEmpty)
                              ? Text(site.url)
                              : Text(site.title!),
                          subtitle: (site.title == null || site.title!.isEmpty)
                              ? Text(Uri.parse(site.url).host)
                              : Text(site.url,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                          dense: true,
                          onTap: () => Get.find<BrowserController>()
                              .lanuchWebview(
                                  content: site.url, defaultTitle: site.title),
                          trailing: IconButton(
                              onPressed: () async {
                                await BrowserHistory.delete(site.id);
                                setState(() {
                                  groupedHistory[dateKey]!.removeAt(index);
                                });
                              },
                              icon: const Icon(Icons.close)),
                        );
                      },
                    )
                  ],
                );
              },
            )));
  }

  String formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future loadData({required int limit, required int offset}) async {
    var list = await BrowserHistory.getAll(limit: limit, offset: offset);
    for (var history in list) {
      String dateKey = formatDateKey(history.createdAt);
      if (!groupedHistory.containsKey(dateKey)) {
        groupedHistory[dateKey] = [];
      }
      groupedHistory[dateKey]!.add(history);
    }
    setState(() {});
  }
}
