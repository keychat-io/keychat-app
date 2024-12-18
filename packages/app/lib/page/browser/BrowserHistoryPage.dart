import 'package:flutter/material.dart';

class BrowserHistoryPage extends StatefulWidget {
  const BrowserHistoryPage({super.key});

  @override
  _BrowserHistoryPageState createState() => _BrowserHistoryPageState();
}

class _BrowserHistoryPageState extends State<BrowserHistoryPage> {
  List historyUrls = [];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('History', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: () {
                  // controller.clearHistory();
                },
                child: const Text('Clear History'),
              ),
            ],
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: historyUrls.length,
            itemBuilder: (context, index) {
              final site = historyUrls[index];
              return ListTile(
                minTileHeight: 4,
                title: site['title'] == null ? null : Text(site['title']!),
                subtitle: site['url'] == null ? null : Text(site['url']!),
                dense: true,
                onTap: () {
                  // controller.lanuchWebview(
                  //     url: site['url']!, defaultTitle: site['title']);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
