import 'dart:io' show File;

import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/setting.controller.dart';
import 'package:app/page/chat/message_actions/VideoPlayWidget.dart';

import 'package:app/service/file_util.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:app/service/file_util.dart' as file_util;
import 'package:share_plus/share_plus.dart';

class ImagePreviewWidget extends StatelessWidget {
  final String localPath;
  final ChatController cc;
  final Widget Function({Widget? child, String? text}) errorCallback;

  const ImagePreviewWidget(
      {super.key,
      required this.localPath,
      required this.cc,
      required this.errorCallback});

  @override
  Widget build(BuildContext context) {
    String filePath = FileUtils.getAbsolutelyFilePath(
        Get.find<SettingController>().appFolder.path, localPath);
    File file = File(filePath);
    if (!file.existsSync()) return errorCallback(text: '[Image cleaned]');
    return GestureDetector(
      onTap: () async {
        // List<File> files = await FileUtils.getRoomImageAndVideo(
        //     cc.room.identityId, cc.room.id);
        // Get.to(
        //     () => SlidesImageViewWidget(
        //         files: files.reversed.toList(), selected: file, file: file),
        //     transition: Transition.zoom,
        //     fullscreenDialog: true);
        bool isImageFile = file_util.isImageFile(file.path);
        Widget child = const Text('Loading');
        if (isImageFile) {
          child = PhotoView.customChild(
            child: Center(child: Image.file(file, fit: BoxFit.contain)),
          );
        } else if (file_util.isVideoFile(file.path)) {
          File thumb = await FileUtils.getOrCreateThumbForVideo(file.path);
          child = VideoPlayWidget(thumb, file.path, true);
        }
        var w = Scaffold(
            floatingActionButton: SizedBox(
                width: Get.width - 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Get.back();
                        },
                      ),
                    ),
                    CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(
                            CupertinoIcons.share,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Share.shareXFiles([XFile(file.path)]);
                          },
                        ))
                  ],
                )),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.miniCenterFloat,
            body: GestureDetector(
                onVerticalDragUpdate: (DragUpdateDetails details) {
                  double dy = details.delta.dy;
                  print('dy: $dy');
                  if (dy > 20) {
                    Get.back();
                  }
                },
                child: child));
        Utils.bottomSheedAndHideStatusBar(w);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 150,
          child: FileUtils.getImageView(file),
        ),
      ),
    );
  }
}
