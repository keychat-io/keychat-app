import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/components.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controller/world.controller.dart';

import 'common.dart';

class WorldPage extends StatelessWidget {
  const WorldPage({super.key});

  @override
  Widget build(context) {
    WorldController worldController = Get.put(WorldController());
    return Obx(() => Scaffold(
          appBar: AppBar(
            title: TabBar(
                controller: worldController.tabController,
                tabs: worldController.feeds.keys
                    .map((e) => Tab(
                          text: '#$e',
                        ))
                    .toList()),
            // title: const Text('Tabs Demo'),
            // actions: [
            //   IconButton(
            //     icon: const Icon(Icons.refresh),
            //     onPressed: () {
            //       worldController.getFeed('bitcoin');
            //       worldController.getFeed('nostr');
            //     },
            //   )
            // ],
          ),
          body: TabBarView(
              controller: worldController.tabController,
              children: worldController.feeds.keys.map((e) {
                List? list = worldController.feeds[e];
                if (list == null || list.isEmpty) {
                  return const SpinKitThreeBounce(
                    color: Colors.purple,
                    size: 30.0,
                    duration: Duration(milliseconds: 2000),
                  );
                  // return const Text('loading...');
                }
                RefreshController refreshController = RefreshController();
                return SmartRefresher(
                    enablePullDown: true,
                    onRefresh: () async {
                      worldController.getFeed(e);
                      refreshController.refreshCompleted();
                    },
                    controller: refreshController,
                    child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder: (BuildContext context, int index) =>
                            Divider(
                              color: Get.isDarkMode
                                  ? Colors.black87
                                  : Colors.white70,
                              thickness: 1.0,
                              height: 1,
                            ),
                        itemBuilder: (BuildContext context, int index) {
                          NostrEventModel ne = list[index];
                          String createdAt = getFormatTimeForMessage(
                              DateTime.fromMillisecondsSinceEpoch(
                                  ne.createdAt * 1000));
                          return ListTile(
                            key: ValueKey(ne.id),
                            leading: const CircleAvatar(
                              backgroundColor: Colors.grey,
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text('user',
                                    style:
                                        Theme.of(context).textTheme.titleSmall),
                                textSmallGray(context, ' · $createdAt')
                              ],
                            ),
                            subtitle: MarkdownBody(
                              onTapLink: (
                                url,
                                url2,
                                url3,
                              ) {
                                final Uri uri = Uri.parse(url);
                                launchUrl(uri);
                              },
                              data: convertToMarkdown(ne.content),
                              imageBuilder: (Uri uri, title, alt) {
                                try {
                                  return CachedNetworkImage(
                                      key: PageStorageKey(uri.toString()),
                                      imageUrl: uri.toString(),
                                      httpHeaders: const {'accept': 'image/*'},
                                      cacheKey: uri.toString(),
                                      memCacheWidth: 100,
                                      imageBuilder: (context, imageProvider) =>
                                          Container(
                                            decoration: BoxDecoration(
                                              image: DecorationImage(
                                                  image: imageProvider,
                                                  fit: BoxFit.cover,
                                                  colorFilter:
                                                      const ColorFilter.mode(
                                                          Colors.red,
                                                          BlendMode.colorBurn)),
                                            ),
                                          ),
                                      placeholder: (context, url) => Text(url),
                                      errorWidget: (context, url, error) =>
                                          Text(url));
                                  // ignore: empty_catches
                                } catch (e) {}
                                return Text(uri.toString());
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            isThreeLine: true,
                            dense: true,
                            // trailing: const Icon(Icons.more_vert),
                            onTap: () {
                              // Handle tap event.
                            },
                          );
                        }));
              }).toList()),
        ));
  }
}

String convertToMarkdown(String text) {
  final regex = RegExp(
      r'(https?://\S+\.(?:jpg|bmp|gif|ico|pcx|jpeg|tif|png|raw))',
      caseSensitive: false);
  return text.replaceAllMapped(regex, (match) => '![](${match.group(0)})');
}
