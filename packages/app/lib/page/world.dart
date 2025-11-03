import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/components.dart';
import 'package:app/utils.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:markdown_widget/markdown_widget.dart';

import 'package:app/controller/world.controller.dart';

class WorldPage extends StatelessWidget {
  const WorldPage({super.key});

  @override
  Widget build(BuildContext context) {
    final worldController = Get.put(WorldController());
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
                final list = worldController.feeds[e];
                if (list == null || list.isEmpty) {
                  return const SpinKitThreeBounce(
                    color: Colors.purple,
                    size: 30,
                    duration: Duration(milliseconds: 2000),
                  );
                  // return const Text('loading...');
                }
                return CustomMaterialIndicator(
                    onRefresh: () => worldController.getFeed(e),
                    displacement: 20,
                    backgroundColor: Colors.white,
                    triggerMode: IndicatorTriggerMode.anywhere,
                    child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder: (BuildContext context2, int index) =>
                            Divider(
                                color: Get.isDarkMode
                                    ? Colors.black87
                                    : Colors.white70,
                                thickness: 1,
                                height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final ne = list[index] as NostrEventModel;
                          final createdAt = Utils.formatTimeForMessage(
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
                            subtitle: MarkdownBlock(
                              // onTapLink: (
                              //   url,
                              //   url2,
                              //   url3,
                              // ) {
                              //   final Uri uri = Uri.parse(url);
                              //   launchUrl(uri);
                              // },
                              data: convertToMarkdown(ne.content),
                              // imageBuilder: (Uri uri, title, alt) {
                              //   try {
                              //     return CachedNetworkImage(
                              //         key: ObjectKey(uri.toString()),
                              //         imageUrl: uri.toString(),
                              //         httpHeaders: const {'accept': 'image/*'},
                              //         cacheKey: uri.toString(),
                              //         memCacheWidth: 100,
                              //         imageBuilder: (context, imageProvider) =>
                              //             Container(
                              //               decoration: BoxDecoration(
                              //                 image: DecorationImage(
                              //                     image: imageProvider,
                              //                     fit: BoxFit.cover,
                              //                     colorFilter:
                              //                         const ColorFilter.mode(
                              //                             Colors.red,
                              //                             BlendMode.colorBurn)),
                              //               ),
                              //             ),
                              //         placeholder: (context, url) => Text(url),
                              //         errorWidget: (context, url, error) =>
                              //             Text(url));
                              //     // ignore: empty_catches
                              //   } catch (e) {}
                              //   return Text(uri.toString());
                              // },
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
