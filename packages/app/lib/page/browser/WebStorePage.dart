import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/models/browser/browser_favorite.dart';
import 'package:keychat/page/browser/MultiWebviewController.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/utils.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class WebStorePage extends StatefulWidget {
  const WebStorePage({super.key});

  @override
  _WebStorePageState createState() => _WebStorePageState();
}

class _WebStorePageState extends State<WebStorePage> {
  late HomeController homeController;
  Set<String> exists = {};
  late MultiWebviewController controller;
  @override
  void initState() {
    controller = Get.find<MultiWebviewController>();
    homeController = Get.find<HomeController>();
    init();
    super.initState();
  }

  Future<void> init() async {
    if (homeController.recommendWebstore.isEmpty) {
      await homeController.loadAppRemoteConfig();
    }
    final List<BrowserFavorite> list = controller.favorites;
    final urls = list.map((e) => e.url).toSet();
    setState(() {
      exists = urls;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Mini App'),
      ),
      body: Obx(
        () => homeController.recommendWebstore.entries.isEmpty
            ? pageLoadingSpinKit()
            : CustomMaterialIndicator(
                onRefresh: () async {
                  await Get.find<HomeController>().loadAppRemoteConfig();
                },
                displacement: 20,
                backgroundColor: Colors.white,
                triggerMode: IndicatorTriggerMode.anywhere,
                child: ListView.builder(
                  itemCount: homeController.recommendWebstore.entries.length,
                  itemBuilder: (context, index) {
                    final entry = homeController.recommendWebstore.entries
                        .elementAt(index);
                    return Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Utils.capitalizeFirstLetter(entry.key.toString()),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: (entry.value as List).length,
                            itemBuilder: (context, index) {
                              final site = (entry.value as List)[index];
                              final url =
                                  (site['url1'] ?? site['url2']) as String;
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Utils.getNeworkImageOrDefault(
                                  site['img'] as String,
                                ),
                                title: Text(
                                  site['title'] as String,
                                  overflow: TextOverflow.fade,
                                  maxLines: 1,
                                ),
                                subtitle: textSmallGray(
                                  context,
                                  site['description'] as String,
                                ),
                                onTap: () {
                                  Get.find<MultiWebviewController>()
                                      .launchWebview(
                                        initUrl: url,
                                        defaultTitle: site['title'] as String,
                                      );
                                  if (Get.isBottomSheetOpen ?? false) {
                                    Get.back<void>();
                                  }
                                },
                                trailing: exists.contains(url)
                                    ? IconButton(
                                        onPressed: () async {
                                          await BrowserFavorite.deleteByUrl(
                                            url,
                                          );
                                          setState(() {
                                            exists = exists..remove(url);
                                          });

                                          EasyLoading.showSuccess(
                                            'Removed from favorites',
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.check,
                                          color: Colors.green,
                                        ),
                                      )
                                    : IconButton(
                                        onPressed: () async {
                                          await BrowserFavorite.add(
                                            url: url,
                                            title: site['title'] as String,
                                            favicon: site['img'] as String,
                                          );
                                          setState(() {
                                            exists = exists..add(url);
                                          });
                                          EasyLoading.showSuccess(
                                            'Added to favorites',
                                          );
                                        },
                                        icon: Icon(
                                          Icons.add,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
