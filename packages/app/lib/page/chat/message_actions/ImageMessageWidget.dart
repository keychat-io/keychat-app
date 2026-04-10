import 'dart:convert' show jsonDecode;

import 'package:flutter/foundation.dart';
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
  ValueNotifier<double>? _progressNotifier;
  Widget? _cachedImageWidget;

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

  @override
  void dispose() {
    _detachProgress();
    super.dispose();
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
      final existing = FileDownloadManager.instance.getProgress(
        widget.message.id,
      );
      if (existing != null) {
        _attachProgress(existing);
        return;
      }

      // Handle stale downloading
      if (mfi.status == FileStatus.downloading && mfi.updateAt != null) {
        final isTimeout = DateTime.now()
            .subtract(FileDownloadManager.staleTimeout)
            .isAfter(mfi.updateAt!);
        if (isTimeout) {
          mfi.status = FileStatus.failed;
        }
      }
      if (mfi.status != FileStatus.decryptSuccess) {
        _cachedImageWidget = null;
      }
      setState(() => fileStatus = mfi.status);
    } catch (e) {
      _cachedImageWidget = null;
      setState(() => fileStatus = FileStatus.failed);
    }
  }

  void _attachProgress(ValueNotifier<double> notifier) {
    _detachProgress();
    _progressNotifier = notifier;
    _progressNotifier!.addListener(_onProgressChanged);
    setState(() => fileStatus = FileStatus.downloading);
  }

  void _detachProgress() {
    _progressNotifier?.removeListener(_onProgressChanged);
    _progressNotifier = null;
  }

  void _onProgressChanged() {
    if (!mounted) return;
    final notifier = _progressNotifier;
    if (notifier == null) return;

    // 1.0 = completed, -1.0 = failed — reload from persisted message state
    if (notifier.value >= 1.0 || notifier.value < 0) {
      _detachProgress();
      _loadState();
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
        // Cache the image widget to avoid rebuilding on unrelated list refreshes
        return _cachedImageWidget ??= ImagePreviewWidget(
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

  void _retryDownload() {
    if (fileInfo == null) return;
    EasyLoading.showToast('Start downloading');
    widget.message.isRead = true;
    final notifier = FileDownloadManager.instance.startDownload(
      widget.message,
      fileInfo!,
    );
    _attachProgress(notifier);
  }
}
