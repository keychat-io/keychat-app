import 'package:app/controller/setting.controller.dart';
import 'package:app/page/setting/BlossomProtocolSetting.dart';
import 'package:app/page/setting/KeychatS3ProtocolSetting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class SelectMediaType extends GetView<SettingController> {
  const SelectMediaType({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Media Relay')),
        body: Obx(
          () => Column(
            children: [
              Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Media server type'))),
              RadioListTile<String>(
                value: MediaServerType.keychatS3.name,
                groupValue: controller.defaultFileMediaType.value,
                title: const Text('Keychat Relay'),
                subtitle: const Text('Pay as you go, powered by Keychat'),
                onChanged: (value) {
                  if (value != null) {
                    controller.setFileMediaType(value);
                    EasyLoading.showSuccess('Success');
                  }
                },
              ),
              RadioListTile<String>(
                value: MediaServerType.blossom.name,
                groupValue: controller.defaultFileMediaType.value,
                title: const Text('Blossom Server'),
                subtitle: const Text(
                    'Monthly/Yearly subscription, powered by other server'),
                onChanged: (value) {
                  if (value != null) {
                    controller.setFileMediaType(value);
                    EasyLoading.showSuccess('Success');
                  }
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
