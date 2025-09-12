import 'package:app/controller/setting.controller.dart';
import 'package:app/page/browser/MultiWebviewController.dart';
import 'package:app/page/setting/KeychatS3ProtocolSetting.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:settings_ui/settings_ui.dart';

class MediaRelaySettings extends GetView<SettingController> {
  const MediaRelaySettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Media Relay'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () {
                final urlController = TextEditingController();

                Get.dialog(CupertinoAlertDialog(
                  title: const Text("Add Server"),
                  content: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.only(top: 15),
                      child: Column(
                        children: [
                          NoticeTextWidget.info(
                              '''1. The server needs to support uploading encrypted files.
2. Each file will be encrypted with a random private key.'''),
                          SizedBox(height: 10),
                          TextField(
                            controller: urlController,
                            textInputAction: TextInputAction.done,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Blossom Server url',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      )),
                  actions: <Widget>[
                    CupertinoDialogAction(
                      child: const Text("Cancel"),
                      onPressed: () {
                        Get.back();
                      },
                    ),
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      onPressed: () async {
                        addUrlSubmit(urlController);
                      },
                      child: const Text("Confirm"),
                    ),
                  ],
                ));
              },
              icon: const Icon(CupertinoIcons.add_circled),
            )
          ],
        ),
        body: Obx(() => controller.mediaServers.isNotEmpty
            ? RadioGroup(
                groupValue: controller.selectedMediaServer.value,
                onChanged: (value) {
                  controller.setSelectedMediaServer(value as String);
                  EasyLoading.showSuccess('Successed');
                },
                child: SettingsList(platform: DevicePlatform.iOS, sections: [
                  SettingsSection(
                    margin:
                        const EdgeInsetsDirectional.symmetric(horizontal: 16),
                    tiles: controller.mediaServers.map((String url) {
                      Uri uri = Uri.parse(url);
                      bool isKeychat = uri.host.contains('keychat.io');
                      return SettingsTile.navigation(
                        title: Text(isKeychat ? uri.host : url),
                        leading: Radio<String>(value: url),
                        onPressed: (context) {
                          if (isKeychat) {
                            Get.to(() => KeychatS3Protocol());
                            return;
                          }
                          Get.bottomSheet(SettingsList(sections: [
                            SettingsSection(
                              title: Text(url),
                              tiles: [
                                SettingsTile.navigation(
                                  title: const Text("View"),
                                  onPressed: (context) {
                                    Get.back();
                                    Get.find<MultiWebviewController>()
                                        .launchWebview(initUrl: url);
                                  },
                                ),
                                SettingsTile(
                                  title: const Text("Copy URL"),
                                  onPressed: (context) {
                                    Get.back();
                                    Clipboard.setData(ClipboardData(text: url));
                                    EasyLoading.showSuccess(
                                        'Copied to clipboard');
                                  },
                                ),
                                SettingsTile(
                                  title: const Text("Delete",
                                      style: TextStyle(color: Colors.red)),
                                  onPressed: (context) {
                                    Get.back();
                                    controller.removeMediaServer(url);
                                    EasyLoading.showSuccess('Removed');
                                  },
                                ),
                              ],
                            )
                          ]));
                        },
                      );
                    }).toList(),
                  )
                ]))
            : const Center(child: Text("No media relay configured yet"))));
  }

  void addUrlSubmit(TextEditingController urlController) {
    String url = urlController.text.trim();
    if (url.isEmpty) {
      EasyLoading.showError('URL cannot be empty');
      return;
    }
    Uri? uri = Uri.tryParse(url);
    if (uri == null ||
        (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
      EasyLoading.showError('Invalid URL');
      return;
    }
    controller.setMediaServers({...controller.mediaServers, url}.toList());

    Get.back();
  }
}
