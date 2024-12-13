import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'Browser_controller.dart';

class BrowserPage extends GetView<BrowserController> {
  const BrowserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // appBar: AppBar(),
        body: GestureDetector(
            onTap: () {
              Utils.hideKeyboard(Get.context!);
            },
            child: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0, vertical: 20),
                    child: Obx(() => ListView(children: [
                          Form(
                            key: const PageStorageKey('input'),
                            child: TextFormField(
                              textInputAction: TextInputAction.go,
                              maxLines: 3,
                              minLines: 1,
                              controller: controller.textController,
                              decoration: InputDecoration(
                                  labelText: 'Url',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (controller.input.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            controller.textController.clear();
                                          },
                                        ),
                                      TextButton(
                                        child: const Text('OK'),
                                        onPressed: () async {
                                          if (controller
                                              .textController.text.isEmpty) {
                                            return;
                                          }
                                          if (controller.textController.text
                                              .startsWith('http')) {
                                            controller.lanuchWebview();
                                          } else {
                                            controller.lanuchWebview(
                                                url:
                                                    'https://${controller.textController.text}');
                                          }
                                        },
                                      ),
                                    ],
                                  )),
                              onFieldSubmitted: (value) {
                                controller.lanuchWebview();
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a URL';
                                }
                                return null;
                              },
                            ),
                          ),
                          if (controller.historyUrls.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 30),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('History',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    TextButton(
                                      onPressed: () {
                                        controller.clearHistory();
                                      },
                                      child: const Text('Clear History'),
                                    ),
                                  ],
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: controller.historyUrls.length,
                                  itemBuilder: (context, index) {
                                    final site = controller.historyUrls[index];
                                    return ListTile(
                                      minTileHeight: 4,
                                      title: site['title'] == null
                                          ? null
                                          : Text(site['title']!),
                                      subtitle: site['url'] == null
                                          ? null
                                          : Text(site['url']!),
                                      dense: true,
                                      onTap: () {
                                        controller.lanuchWebview(
                                            url: site['url'],
                                            defaultTitle: site['title']);
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          const SizedBox(height: 30),
                          Text('Recommended URLs',
                              style: Theme.of(context).textTheme.titleMedium),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: controller.recommendedUrls.length,
                            itemBuilder: (context, index) {
                              final site = controller.recommendedUrls[index];
                              return ListTile(
                                title: Text(site['title']),
                                subtitle: Text(site['url']),
                                minTileHeight: 4,
                                dense: true,
                                onTap: () {
                                  controller.lanuchWebview(
                                      url: site['url'],
                                      defaultTitle: site['title']);
                                },
                              );
                            },
                          ),
                        ]))))));
  }
}
