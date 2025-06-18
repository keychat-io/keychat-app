import 'package:app/controller/setting.controller.dart';
import 'package:app/page/setting/BlossomProtocolSetting.dart';
import 'package:app/page/setting/KeychatS3ProtocolSetting.dart';
import 'package:app/page/widgets/notice_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class SelectMediaType extends GetView<SettingController> {
  const SelectMediaType({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Media Servers'),
        ),
        body: Obx(
          () => Column(
            children: [
              NoticeTextWidget.success(
                  'All files will be encrypted by one-timekey.'),
              ListTile(
                trailing: controller.defaultFileMediaType.value ==
                        MediaServerType.blossom.name
                    ? const Icon(Icons.check_circle)
                    : null,
                selected: controller.defaultFileMediaType.value ==
                    MediaServerType.blossom.name,
                title: const Text('Blossom Server'),
                subtitle: const Text(
                    'Monthly/Yearly subscription, powered by other server'),
                onTap: () {
                  controller.seteFileMediaType(MediaServerType.blossom.name);
                  EasyLoading.showSuccess('Success');
                },
              ),
              ListTile(
                trailing: controller.defaultFileMediaType.value ==
                        MediaServerType.keychatS3.name
                    ? const Icon(Icons.check_circle)
                    : null,
                selected: controller.defaultFileMediaType.value ==
                    MediaServerType.keychatS3.name,
                title: const Text('Keychat S3'),
                subtitle: const Text('Pay as you go, powered by Keychat'),
                onTap: () {
                  controller.seteFileMediaType(MediaServerType.keychatS3.name);
                  EasyLoading.showSuccess('Success');
                },
              ),
              controller.defaultFileMediaType.value ==
                      MediaServerType.keychatS3.name
                  ? KeychatS3Protocol()
                  : BlossomProtocolSetting()
            ],
          ),
        ));
  }
}
