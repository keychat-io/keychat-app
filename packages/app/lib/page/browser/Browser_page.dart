import 'package:app/page/browser/BrowserSetting.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'Browser_controller.dart';

class BrowserPage extends GetView<BrowserController> {
  const BrowserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(CupertinoIcons.home),
            onPressed: () {},
          ),
          actions: [
            Obx(() => getRandomAvatar(controller.identity.value.secp256k1PKHex,
                height: 22, width: 22)),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                Get.to(() => const BrowserSetting());
              },
            )
          ],
        ),
        body: GestureDetector(
            onTap: () {
              Utils.hideKeyboard(Get.context!);
            },
            child: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Obx(() => ListView(children: [
                          ...controller.enableSearchEngine.map((engine) =>
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Form(
                                    key: PageStorageKey('input:$engine'),
                                    child: TextFormField(
                                      textInputAction: TextInputAction.go,
                                      maxLines: 1,
                                      controller: controller.textController,
                                      decoration: InputDecoration(
                                          labelText:
                                              Utils.capitalizeFirstLetter(
                                                  engine),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(100.0),
                                          ),
                                          suffixIcon: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (controller.input.isNotEmpty)
                                                IconButton(
                                                  icon: const Icon(Icons.clear),
                                                  onPressed: () {
                                                    controller.textController
                                                        .clear();
                                                  },
                                                ),
                                              TextButton(
                                                child: const Text('OK'),
                                                onPressed: () async {
                                                  if (controller.textController
                                                      .text.isEmpty) {
                                                    return;
                                                  }
                                                  controller.lanuchWebview(
                                                      content: controller
                                                          .textController.text
                                                          .trim(),
                                                      engine: engine);
                                                },
                                              ),
                                            ],
                                          )),
                                      onFieldSubmitted: (value) {
                                        controller.lanuchWebview(
                                            engine: engine,
                                            content: controller
                                                .textController.text
                                                .trim());
                                      },
                                    ),
                                  ))),
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
                                      engine: BrowserEngine.google.name,
                                      content: site['url'],
                                      defaultTitle: site['title']);
                                },
                              );
                            },
                          ),
                        ]))))));
  }
}
