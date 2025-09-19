import 'dart:io' show File;

import 'package:app/controller/chat.controller.dart';
import 'package:app/page/chat/message_actions/VideoPlayWidget.dart';
import 'package:app/service/file.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

class ImagePreviewWidget extends StatelessWidget {
  const ImagePreviewWidget(
      {required this.localPath,
      required this.cc,
      required this.errorCallback,
      super.key});
  final String localPath;
  final ChatController cc;
  final Widget Function({Widget? child, String? text}) errorCallback;

  @override
  Widget build(BuildContext context) {
    final filePath = FileService.instance
        .getAbsolutelyFilePath(Utils.appFolder.path, localPath);
    final file = File(filePath);
    if (!file.existsSync()) return errorCallback(text: '[Image cleaned]');
    return GestureDetector(
      onTap: () async {
        // List<File> files = await FileService.instance.getRoomImageAndVideo(
        //     cc.room.identityId, cc.room.id);
        // Get.to(
        //     () => SlidesImageViewWidget(
        //         files: files.reversed.toList(), selected: file, file: file),
        //     transition: Transition.zoom,
        //     fullscreenDialog: true);
        final isImageFile = FileService.instance.isImageFile(file.path);
        Widget child = const Text('Loading');
        if (isImageFile) {
          child = PhotoView.customChild(
            child: Center(child: Image.file(file, fit: BoxFit.contain)),
          );
        } else if (FileService.instance.isVideoFile(file.path)) {
          final thumb =
              await FileService.instance.getOrCreateThumbForVideo(file.path);
          child = VideoPlayWidget(thumb, file.path, true);
        }
        final w = Scaffold(
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
                          Get.back<void>();
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
                            SharePlus.instance.share(ShareParams(
                                previewThumbnail: XFile(file.path),
                                files: [XFile(filePath)],
                                subject: FileService.instance
                                    .getDisplayFileName(file.path)));
                          },
                        ))
                  ],
                )),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.miniCenterFloat,
            body: GestureDetector(
                onVerticalDragUpdate: (DragUpdateDetails details) {
                  final dy = details.delta.dy;
                  if (dy > 20) {
                    Get.back<void>();
                  }
                },
                child: child));
        Utils.bottomSheedAndHideStatusBar(w);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 150,
          child: FileService.instance.getImageView(file),
        ),
      ),
    );
  }
}
