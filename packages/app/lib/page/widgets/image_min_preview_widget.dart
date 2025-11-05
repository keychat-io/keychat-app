import 'dart:io' show File;
import 'package:keychat/service/file.service.dart';
import 'package:keychat/utils.dart';
import 'package:flutter/material.dart';

class ImageMinPreviewWidget extends StatelessWidget {
  const ImageMinPreviewWidget(this.localPath, {super.key});
  final String localPath;

  @override
  Widget build(BuildContext context) {
    final filePath = FileService.instance.getAbsolutelyFilePath(
      Utils.appFolder.path,
      localPath,
    );
    final file = File(filePath);
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
