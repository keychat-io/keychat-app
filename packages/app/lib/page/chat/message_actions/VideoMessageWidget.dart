import 'dart:convert' show jsonDecode;
import 'dart:io' show File;

import 'package:app/app.dart';
import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/setting.controller.dart';
import 'package:app/page/widgets/image_slide_widget.dart';
import 'package:app/service/file_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class VideoMessageWidget extends StatefulWidget {
  final Message message;
  final Widget Function({Widget? child, String? text}) errorCallback;
  const VideoMessageWidget(this.message, this.errorCallback, {super.key});

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
    appFolder = Get.find<SettingController>().appFolder.path;
    try {
      MsgFileInfo mfi =
          MsgFileInfo.fromJson(jsonDecode(widget.message.realMessage!));
      _init(mfi);
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  _init(MsgFileInfo mfi) {
    if (mfi.status == FileStatus.downloading && mfi.updateAt != null) {
      bool isTimeout = DateTime.now()
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
      String filePath = '$appFolder${mfi.localPath!}';
      bool fileExists = File(filePath).existsSync();
      if (fileExists == false) {
        setState(() {
          fileStatus = FileStatus.init;
          msgFileInfo = mfi;
        });
        return;
      }
      String thumbnail = FileUtils.getVideoThumbPath(filePath);
      File tFile = File(thumbnail);
      if (tFile.existsSync()) {
        setState(() {
          fileStatus = FileStatus.decryptSuccess;
          msgFileInfo = mfi;
          thumbnailFile = tFile;
          videoPath = filePath;
        });
        return;
      }
      FileUtils.getOrCreateThumbForVideo(filePath).then((value) {
        value.copySync(tFile.path);
        setState(() {
          fileStatus = FileStatus.decryptSuccess;
          msgFileInfo = mfi;
          thumbnailFile = tFile;
          videoPath = filePath;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (fileStatus == FileStatus.init || fileStatus == FileStatus.failed) {
      return Row(
        children: [
          widget.errorCallback(
              text:
                  '[Video File]:  ${fileStatus == FileStatus.failed ? 'Download Failed' : FileUtils.getFileSizeDisplay(msgFileInfo?.size ?? 0)}'),
          IconButton(
            onPressed: () {
              if (msgFileInfo == null) return;
              EasyLoading.showToast('Start downloading');
              FileUtils.downloadForMessage(widget.message, msgFileInfo!,
                  callback: _init, onReceiveProgress: (int count, int total) {
                setState(() {
                  downloadProgress = (count / total * 100).toStringAsFixed(2);
                });
              });
            },
            icon: Icon(
              Icons.download_sharp,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          )
        ],
      );
    }

    if (fileStatus == FileStatus.downloading) {
      return Row(
        children: [
          widget.errorCallback(text: '[Downloading]: $downloadProgress%'),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.downloading_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          )
        ],
      );
    }

    return thumbnailFile == null
        ? const Text('Video')
        : Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                      width: 150,
                      child: Image.file(thumbnailFile!, fit: BoxFit.contain))),
              Positioned(
                child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey.withValues(alpha: 0.8),
                    child: IconButton(
                      onPressed: () async {
                        ChatController? cc =
                            RoomService.getController(widget.message.roomId);
                        if (cc == null || videoPath == null) return;
                        List<File> files = await FileUtils.getRoomImageAndVideo(
                            cc.room.identityId, cc.room.id);
                        Get.to(
                            () => SlidesImageViewWidget(
                                files: files.reversed.toList(),
                                selected: File(videoPath!),
                                file: thumbnailFile!),
                            transition: Transition.zoom,
                            fullscreenDialog: true);
                      },
                      icon: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                    )),
              ),
            ],
          );
  }
}
