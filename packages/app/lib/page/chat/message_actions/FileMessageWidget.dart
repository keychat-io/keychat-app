import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/page/chat/message_actions/FileMessagePreview.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/service/file_download_manager.dart';

class FileMessageWidget extends StatefulWidget {
  const FileMessageWidget(this.message, this.errorCallback, {super.key});
  final Message message;
  final Widget Function({Widget? child, String? text}) errorCallback;

  @override
  State<FileMessageWidget> createState() => _FileMessageWidgetState();
}

class _FileMessageWidgetState extends State<FileMessageWidget> {
  bool decodeError = false;
  MsgFileInfo? msgFileInfo;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void didUpdateWidget(FileMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.realMessage != widget.message.realMessage) {
      _loadState();
    }
  }

  void _loadState() {
    try {
      if (widget.message.realMessage == null) {
        throw Exception('realMessage is null');
      }
      final mfi = MsgFileInfo.fromJson(
        jsonDecode(widget.message.realMessage!) as Map<String, dynamic>,
      );
      setState(() {
        msgFileInfo = mfi;
        decodeError = false;
      });
    } catch (e) {
      setState(() => decodeError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (decodeError || msgFileInfo == null) {
      return widget.errorCallback(
        text: '[File Decode Error]: ${widget.message.content}',
      );
    }
    final isDownloaded = msgFileInfo!.localPath != null &&
        msgFileInfo!.status == FileStatus.decryptSuccess;
    final isDownloading = FileDownloadManager.instance.isDownloading(
      widget.message.id,
    );
    return Container(
      constraints: const BoxConstraints(maxWidth: 350),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        title: Text(
          msgFileInfo?.fileName ??
              msgFileInfo?.suffix?.toUpperCase() ??
              '[File]',
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: textSmallGray(
          context,
          isDownloading
              ? 'Downloading...'
              : 'Size: ${FileService.instance.getFileSizeDisplay(msgFileInfo?.size ?? 0)}',
        ),
        trailing: SizedBox(
          width: 36,
          height: 36,
          child: isDownloading
              ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  onPressed: _handleOnTap,
                  padding: EdgeInsets.zero,
                  icon: Image.asset(
                    isDownloaded
                        ? 'assets/images/file.png'
                        : 'assets/images/file-download.png',
                    fit: BoxFit.contain,
                  ),
                ),
        ),
        onTap: _handleOnTap,
      ),
    );
  }

  void _handleOnTap() {
    if (msgFileInfo != null) {
      // ignore: discarded_futures -- bottomSheet future is not needed here
      Get.bottomSheet<void>(FileMessagePreview(widget.message, msgFileInfo!));
    }
  }
}
