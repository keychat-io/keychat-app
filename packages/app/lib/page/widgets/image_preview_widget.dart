import 'dart:io' show Directory, File;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/controller/chat.controller.dart';
import 'package:keychat/page/chat/message_actions/VideoPlayWidget.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/utils.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory, getDownloadsDirectory;
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

Future<File> _savePreviewFileToDownloads(File source) async {
  final downloadDirectory = await _getUserDownloadDirectory();
  await downloadDirectory.create(recursive: true);

  final destinationPath = _getAvailableDownloadPath(
    downloadDirectory.path,
    path.basename(source.path),
  );
  return source.copy(destinationPath);
}

Future<Directory> _getUserDownloadDirectory() async {
  try {
    final downloadsDirectory = await getDownloadsDirectory();
    if (downloadsDirectory != null) {
      return downloadsDirectory;
    }
  } catch (e) {
    logger.w('Unable to resolve downloads directory: $e');
  }
  return getApplicationDocumentsDirectory();
}

String _getAvailableDownloadPath(String directoryPath, String fileName) {
  final safeFileName = path.basename(fileName);
  final baseName = path.basenameWithoutExtension(safeFileName).isEmpty
      ? 'keychat_image'
      : path.basenameWithoutExtension(safeFileName);
  final extension = path.extension(safeFileName);

  var index = 0;
  while (true) {
    final outputName = index == 0
        ? '$baseName$extension'
        : '$baseName ($index)$extension';
    final candidatePath = path.join(directoryPath, outputName);
    if (!File(candidatePath).existsSync()) {
      return candidatePath;
    }
    index++;
  }
}

class ImagePreviewWidget extends StatelessWidget {
  const ImagePreviewWidget({
    required this.localPath,
    required this.cc,
    required this.errorCallback,
    super.key,
  });
  final String localPath;
  final ChatController cc;
  final Widget Function({Widget? child, String? text}) errorCallback;

  @override
  Widget build(BuildContext context) {
    final filePath = FileService.instance.getAbsolutelyFilePath(
      Utils.appFolder.path,
      localPath,
    );
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
          final thumb = await FileService.instance.getOrCreateThumbForVideo(
            file.path,
          );
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
                    onPressed: () async {
                      try {
                        final box = context.findRenderObject() as RenderBox?;
                        await SharePlus.instance.share(
                          ShareParams(
                            previewThumbnail: XFile(filePath),
                            files: [XFile(filePath)],
                            subject: FileService.instance.getDisplayFileName(
                              file.path,
                            ),
                            sharePositionOrigin:
                                box!.localToGlobal(Offset.zero) & box.size,
                          ),
                        );
                      } catch (e) {
                        logger.e(e);
                      }
                    },
                  ),
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(
                      CupertinoIcons.arrow_down_to_line,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      await _downloadFile(file);
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.miniCenterFloat,
          body: GestureDetector(
            onVerticalDragUpdate: (details) {
              final dy = details.delta.dy;
              if (dy > 20) {
                Get.back<void>();
              }
            },
            child: child,
          ),
        );
        await Utils.bottomSheedAndHideStatusBar(w);
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

  Future<void> _downloadFile(File file) async {
    await EasyLoading.show(status: 'Saving...');
    try {
      final savedFile = await _savePreviewFileToDownloads(file);
      await EasyLoading.dismiss();
      final destinationFolder = path.basename(path.dirname(savedFile.path));
      await EasyLoading.showSuccess(
        'Saved to $destinationFolder/'
        '${FileService.instance.getDisplayFileName(savedFile.path)}',
      );
    } catch (e, s) {
      await EasyLoading.dismiss();
      await EasyLoading.showError('Save failed');
      logger.e('Failed to save preview file', error: e, stackTrace: s);
    }
  }
}
