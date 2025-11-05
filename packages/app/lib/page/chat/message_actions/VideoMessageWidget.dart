import 'dart:convert' show jsonDecode;
import 'dart:io' show File;

import 'package:keychat/app.dart';
import 'package:keychat/page/widgets/image_slide_widget.dart';
import 'package:keychat/service/file.service.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class VideoMessageWidget extends StatefulWidget {
  const VideoMessageWidget(this.message, this.errorCallback, {super.key});
  final Message message;
  final Widget Function({Widget? child, String? text}) errorCallback;

  @override
  _VideoMessageWidgetState createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  File? thumbnailFile;
  String? videoPath;
  FileStatus fileStatus = FileStatus.init;
  MsgFileInfo? msgFileInfo;
  String downloadProgress = '0.00';
  late String appFolder;

  @override
  void initState() {
    super.initState();
    appFolder = Utils.appFolder.path;
    try {
      final mfi = MsgFileInfo.fromJson(jsonDecode(widget.message.realMessage!));
      _init(mfi);
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  Future<void> _init(MsgFileInfo mfi) async {
    if (mfi.status == FileStatus.downloading && mfi.updateAt != null) {
      final isTimeout = DateTime.now()
          .subtract(const Duration(seconds: 120))
          .isAfter(mfi.updateAt!);
      if (isTimeout) {
        mfi.status = FileStatus.failed;
      }
    }
    // other status
    if (mfi.status != FileStatus.decryptSuccess) {
      setState(() {
        fileStatus = mfi.status;
        msgFileInfo = mfi;
      });
      return;
    }
    // decryptSuccess
    if (mfi.status == FileStatus.decryptSuccess && mfi.localPath != null) {
      final filePath = '$appFolder${mfi.localPath!}';
      final fileExists = File(filePath).existsSync();
      if (!fileExists) {
        setState(() {
          fileStatus = FileStatus.init;
          msgFileInfo = mfi;
        });
        return;
      }
      setState(() {
        fileStatus = FileStatus.decryptSuccess;
        msgFileInfo = mfi;
        videoPath = filePath;
      });

      FileService.instance.getOrCreateThumbForVideo(filePath).then((value) {
        setState(() {
          thumbnailFile = value;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (fileStatus == FileStatus.init || fileStatus == FileStatus.failed) {
      return Wrap(
        children: [
          widget.errorCallback(
            text:
                '[Video File]: ${fileStatus == FileStatus.failed ? 'Download Failed' : FileService.instance.getFileSizeDisplay(msgFileInfo?.size ?? 0)}',
          ),
          IconButton(
            onPressed: () {
              if (msgFileInfo == null) return;
              EasyLoading.showToast('Start downloading');
              FileService.instance.downloadForMessage(
                widget.message,
                msgFileInfo!,
                callback: _init,
                onReceiveProgress: (int count, int total) {
                  EasyDebounce.debounce(
                    'downloadProgress',
                    const Duration(milliseconds: 300),
                    () {
                      setState(() {
                        downloadProgress = (count / total * 100)
                            .toStringAsFixed(2);
                      });
                    },
                  );
                },
              );
            },
            icon: Icon(
              Icons.download_sharp,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );
    }

    if (fileStatus == FileStatus.downloading) {
      return Wrap(
        children: [
          widget.errorCallback(text: '[Downloading]- $downloadProgress%'),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.downloading_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );
    }

    return thumbnailFile == null
        ? FileMessageWidget(widget.message, widget.errorCallback)
        : Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 150,
                  child: Image.file(thumbnailFile!, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey.withValues(alpha: 0.8),
                  child: IconButton(
                    onPressed: () async {
                      final cc = RoomService.getController(
                        widget.message.roomId,
                      );
                      if (cc == null || videoPath == null) return;
                      final files = await FileService.instance
                          .getRoomImageAndVideo(
                            cc.roomObs.value.identityId,
                            cc.roomObs.value.id,
                          );
                      Get.to(
                        () => SlidesImageViewWidget(
                          files: files.reversed.toList(),
                          selected: File(videoPath!),
                          file: thumbnailFile,
                        ),
                        transition: Transition.zoom,
                        fullscreenDialog: true,
                      );
                    },
                    icon: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}
