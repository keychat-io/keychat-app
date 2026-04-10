import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:keychat/app.dart';
import 'package:keychat/controller/chat.controller.dart';
import 'package:keychat/page/widgets/image_preview_widget.dart';
import 'package:keychat/service/file_download_manager.dart';

class ImageMessageWidget extends StatefulWidget {
  const ImageMessageWidget({
    required this.message,
    required this.cc,
    required this.errorCallback,
    super.key,
  });
  final Message message;
  final ChatController cc;
  final Widget Function({Widget? child, String? text}) errorCallback;

  @override
  State<ImageMessageWidget> createState() => _ImageMessageWidgetState();
}

class _ImageMessageWidgetState extends State<ImageMessageWidget> {
  MsgFileInfo? fileInfo;
  FileStatus fileStatus = FileStatus.init;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void didUpdateWidget(ImageMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.realMessage != widget.message.realMessage) {
      _loadState();
    }
  }

  void _loadState() {
    if (widget.message.realMessage == null) {
      setState(() => fileStatus = FileStatus.failed);
      return;
    }
    try {
      final mfi = MsgFileInfo.fromJson(
        jsonDecode(widget.message.realMessage!) as Map<String, dynamic>,
      );
      fileInfo = mfi;

      // Check manager for active download
      if (FileDownloadManager.instance.isDownloading(widget.message.id)) {
        setState(() => fileStatus = FileStatus.downloading);
        return;
      }

      // Handle stale downloading
      if (mfi.status == FileStatus.downloading && mfi.updateAt != null) {
        final isTimeout = DateTime.now()
            .subtract(const Duration(seconds: 60))
            .isAfter(mfi.updateAt!);
        if (isTimeout) {
          mfi.status = FileStatus.failed;
        }
      }
      setState(() => fileStatus = mfi.status);
    } catch (e) {
      setState(() => fileStatus = FileStatus.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (fileStatus) {
      case FileStatus.downloading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.errorCallback(text: 'Downloading...'),
            const SpinKitFadingCircle(color: Color(0xfff0aa35), size: 25),
          ],
        );
      case FileStatus.decryptSuccess:
        if (fileInfo?.localPath == null) {
          return widget.errorCallback(text: '[Image Loading]');
        }
        return ImagePreviewWidget(
          localPath: fileInfo!.localPath!,
          cc: widget.cc,
          errorCallback: widget.errorCallback,
        );
      case FileStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.errorCallback(text: '[Image Crashed]'),
            IconButton(
              onPressed: _retryDownload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        );
      // ignore: deprecated_member_use_from_same_package
      case FileStatus.downloaded:
      case FileStatus.init:
        return widget.errorCallback(text: '[Image Loading]');
    }
  }

  Future<void> _retryDownload() async {
    if (fileInfo == null) return;
    await EasyLoading.showToast('Start downloading');
    widget.message.isRead = true;
    FileDownloadManager.instance.startDownload(widget.message, fileInfo!);
    setState(() => fileStatus = FileStatus.downloading);
  }
}
