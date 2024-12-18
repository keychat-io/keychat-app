import 'package:app/models/browser/browser_history.dart';
import 'package:app/page/browser/Browser_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class BrowserHistoryPage extends StatefulWidget {
  const BrowserHistoryPage({super.key});

  @override
  _BrowserHistoryPageState createState() => _BrowserHistoryPageState();
}

class _BrowserHistoryPageState extends State<BrowserHistoryPage> {
  List<BrowserHistory> historyUrls = [];
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
                  await BrowserHistory.deleteAll();
                  setState(() {
                    historyUrls = [];
                  });
                })
          ],
        ),
        body: SmartRefresher(
            enablePullDown: true,
            onLoading: () async {
              await loadData(limit: 20, offset: historyUrls.length);
              refreshController.loadComplete();
            },
            controller: refreshController,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: historyUrls.length,
              itemBuilder: (context, index) {
                final site = historyUrls[index];
                return ListTile(
                  leading: Text(formatDate(site.createdAt)),
                  minTileHeight: 4,
                  title: site.title == null ? null : Text(site.title!),
                  subtitle: Text(site.url,
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  dense: true,
                  onTap: () {
                    Get.find<BrowserController>().lanuchWebview(
                        content: site.url, defaultTitle: site.title);
                  },
                );
              },
            )));
  }

  Future loadData({required int limit, required int offset}) async {
    var list = await BrowserHistory.getAll(limit: limit, offset: offset);
    historyUrls.addAll(list);
    setState(() {
      historyUrls = [...historyUrls];
    });
  }

  String formatDate(DateTime createdAt) {
    final now = DateTime.now();
    if (now.year == createdAt.year) {
      if (now.day == createdAt.day) {
        return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
      } else {
        return '${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
      }
    } else {
      return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    }
  }
}
