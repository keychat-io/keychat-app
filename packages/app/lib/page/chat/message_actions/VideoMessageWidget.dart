import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode;
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/page/widgets/image_slide_widget.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/service/file_download_manager.dart';

class VideoMessageWidget extends StatefulWidget {
  const VideoMessageWidget(this.message, this.errorCallback, {super.key});
  final Message message;
  final Widget Function({Widget? child, String? text}) errorCallback;

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  File? thumbnailFile;
  String? videoPath;
  FileStatus fileStatus = FileStatus.init;
  MsgFileInfo? msgFileInfo;
  double? downloadProgress;
  late String appFolder;
  ValueNotifier<double>? _progressNotifier;

  @override
  void initState() {
    super.initState();
    appFolder = Utils.appFolder.path;
    _loadState();
  }

  @override
  void didUpdateWidget(VideoMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.realMessage != widget.message.realMessage) {
      _loadState();
    }
  }

  @override
  void dispose() {
    _detachProgress();
    super.dispose();
  }

  void _loadState() {
    try {
      if (widget.message.realMessage == null) return;
      final mfi = MsgFileInfo.fromJson(
        jsonDecode(widget.message.realMessage!) as Map<String, dynamic>,
      );
      msgFileInfo = mfi;

      // Check for active download in manager first
      final existing = FileDownloadManager.instance.getProgress(
        widget.message.id,
      );
      if (existing != null) {
        _attachProgress(existing);
        return;
      }

      // Handle stale downloading state
      if (mfi.status == FileStatus.downloading && mfi.updateAt != null) {
        final isTimeout = DateTime.now()
            .subtract(const Duration(seconds: 120))
            .isAfter(mfi.updateAt!);
        if (isTimeout) {
          mfi.status = FileStatus.failed;
        }
      }

      if (mfi.status == FileStatus.decryptSuccess && mfi.localPath != null) {
        _loadCompletedVideo(mfi);
      } else {
        setState(() {
          fileStatus = mfi.status;
          downloadProgress = null;
        });
        // Auto-download small videos for received messages
        if (mfi.status == FileStatus.init && !widget.message.isMeSend) {
          if (mfi.size > 0 && mfi.size <= 20 * 1024 * 1024) {
            _startDownload();
          }
        }
      }
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  void _loadCompletedVideo(MsgFileInfo mfi) {
    final filePath = '$appFolder${mfi.localPath!}';
    if (!File(filePath).existsSync()) {
      setState(() {
        fileStatus = FileStatus.init;
      });
      return;
    }
    setState(() {
      fileStatus = FileStatus.decryptSuccess;
      videoPath = filePath;
    });
    unawaited(
      FileService.instance.getOrCreateThumbForVideo(filePath).then((value) {
        if (mounted) setState(() => thumbnailFile = value);
      }),
    );
  }

  void _startDownload() {
    if (msgFileInfo == null) return;
    final notifier = FileDownloadManager.instance.startDownload(
      widget.message,
      msgFileInfo!,
    );
    _attachProgress(notifier);
  }

  void _attachProgress(ValueNotifier<double> notifier) {
    _detachProgress();
    _progressNotifier = notifier;
    _progressNotifier!.addListener(_onProgressChanged);
    setState(() {
      fileStatus = FileStatus.downloading;
      downloadProgress = notifier.value;
    });
  }

  void _detachProgress() {
    _progressNotifier?.removeListener(_onProgressChanged);
    _progressNotifier = null;
  }

  void _onProgressChanged() {
    if (!mounted) return;
    final notifier = _progressNotifier;
    if (notifier == null) return;

    setState(() => downloadProgress = notifier.value);

    // When manager removes the entry, download is done — reload from message
    if (!FileDownloadManager.instance.isDownloading(widget.message.id)) {
      _detachProgress();
      _loadState();
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
              unawaited(EasyLoading.showToast('Start downloading'));
              _startDownload();
            },
            icon: Icon(
              fileStatus == FileStatus.failed ? Icons.refresh : Icons.download_sharp,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );
    }

    if (fileStatus == FileStatus.downloading) {
      final pct = downloadProgress ?? 0;
      return Wrap(
        children: [
          widget.errorCallback(
            text: '[Downloading] ${(pct * 100).toStringAsFixed(1)}%',
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
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
                      unawaited(
                        Get.to<void>(
                          () => SlidesImageViewWidget(
                            files: files.reversed.toList(),
                            selected: File(videoPath!),
                            file: thumbnailFile,
                          ),
                          transition: Transition.zoom,
                          fullscreenDialog: true,
                        ),
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
