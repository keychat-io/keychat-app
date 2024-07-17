import 'dart:io' show File;

import 'package:app/controller/setting.controller.dart';
import 'package:app/service/file_util.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ImageMinPreviewWidget extends StatelessWidget {
  final String localPath;

  const ImageMinPreviewWidget(this.localPath, {super.key});

  @override
  Widget build(BuildContext context) {
    SettingController settingController = Get.find<SettingController>();
    String filePath = FileUtils.getAbsolutelyFilePath(
        settingController.appFolder.path, localPath);
    File file = File(filePath);
    if (!file.existsSync()) return const Text('[File cleaned]');

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 90,
        height: 160,
        child: Image.file(
          file,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
