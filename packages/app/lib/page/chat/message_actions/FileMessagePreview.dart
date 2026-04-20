import 'dart:convert' show jsonDecode;
import 'dart:io' show File;

import 'package:keychat/models/embedded/msg_file_info.dart';
import 'package:keychat/models/message.dart';
import 'package:keychat/page/components.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/service/file_download_manager.dart';
import 'package:keychat/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

class FileMessagePreview extends StatefulWidget {
  const FileMessagePreview(this.message, this.mfi, {super.key});
  final Message message;
  final MsgFileInfo mfi;

  @override
  _FileMessagePreviewState createState() => _FileMessagePreviewState();
}

class _FileMessagePreviewState extends State<FileMessagePreview> {
  FileStatus fileStatus = FileStatus.init;
  late MsgFileInfo msgFileInfo;
  late String fileSize;
  double downloadProgress = 0;
  ValueNotifier<double>? _progressNotifier;

  @override
  void initState() {
    msgFileInfo = widget.mfi;
    fileSize = FileService.instance.getFileSizeDisplay(msgFileInfo.size);
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _detachProgress();
    super.dispose();
  }

  void _loadState() {
    // Check manager first
    final existing = FileDownloadManager.instance.getProgress(
      widget.message.id,
    );
    if (existing != null) {
      _attachProgress(existing);
      return;
    }

    final mfi = msgFileInfo;
    if (mfi.status == FileStatus.downloading && mfi.updateAt != null) {
      final isTimeout = DateTime.now()
          .subtract(FileDownloadManager.staleTimeout)
          .isAfter(mfi.updateAt!);
      if (isTimeout) {
        mfi.status = FileStatus.failed;
      }
    }
    if (mfi.status == FileStatus.decryptSuccess && mfi.localPath != null) {
      final filePath = '${Utils.appFolder.path}${mfi.localPath!}';
      if (!File(filePath).existsSync()) {
        setState(() {
          fileStatus = FileStatus.init;
        });
        return;
      }
    }
    setState(() {
      fileStatus = mfi.status;
    });
  }

  void _startDownload() {
    final notifier = FileDownloadManager.instance.startDownload(
      widget.message,
      msgFileInfo,
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

    // 1.0 = completed, -1.0 = failed — reload from persisted message state
    if (notifier.value >= 1.0 || notifier.value < 0) {
      _detachProgress();
      // Re-read mfi from message for final state
      try {
        msgFileInfo = MsgFileInfo.fromJson(
          jsonDecode(widget.message.realMessage!) as Map<String, dynamic>,
        );
      } catch (_) {}
      _loadState();
      return;
    }
    setState(() => downloadProgress = notifier.value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File'),
        actions: [
          if (fileStatus == FileStatus.decryptSuccess &&
              msgFileInfo.localPath != null)
            IconButton(
              onPressed: () async {
                final filePath =
                    '${Utils.appFolder.path}${msgFileInfo.localPath!}';
                final fileExists = File(filePath).existsSync();
                if (fileExists) {
                  await File(filePath).delete();
                }
                EasyLoading.showToast('File deleted');
                _loadState();
              },
              icon: const Icon(CupertinoIcons.delete),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                msgFileInfo.fileName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Size: ${FileService.instance.getFileSizeDisplay(msgFileInfo.size)}',
              ),
              textSmallGray(
                context,
                'Encrypted by AES-256-CTR with one-time key',
              ),
              if (fileStatus == FileStatus.downloading && downloadProgress > 0)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LinearProgressIndicator(value: downloadProgress),
                ),
              const SizedBox(height: 16),
              getStatusButton(),
              if (fileStatus == FileStatus.decryptSuccess &&
                  msgFileInfo.localPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final filePath =
                          '${Utils.appFolder.path}${msgFileInfo.localPath!}';
                      final box = context.findRenderObject() as RenderBox?;
                      SharePlus.instance.share(
                        ShareParams(
                          previewThumbnail: XFile(filePath),
                          files: [XFile(filePath)],
                          subject: FileService.instance.getDisplayFileName(
                            msgFileInfo.localPath!,
                          ),
                          sharePositionOrigin:
                              box!.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    },
                    icon: const Icon(CupertinoIcons.share),
                    label: const Text('More'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget getStatusButton() {
    switch (fileStatus) {
      case FileStatus.decryptSuccess:
        return Wrap(
          direction: Axis.vertical,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          children: [
            FilledButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                final filePath =
                    '${Utils.appFolder.path}${msgFileInfo.localPath!}';
                if (GetPlatform.isDesktop) {
                  final dir = filePath.substring(0, filePath.lastIndexOf('/'));
                  OpenFilex.open(dir);
                } else {
                  OpenFilex.open(filePath);
                }
              },
              child: Text(
                GetPlatform.isDesktop ? 'View in Finder' : 'Open in Other App',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                final filePath =
                    '${Utils.appFolder.path}${msgFileInfo.localPath!}';
                final fileName = path.basename(msgFileInfo.localPath!);
                final outputFile = await FilePicker.platform.saveFile(
                  dialogTitle: 'Please select an output path:',
                  fileName: fileName,
                  bytes: await File(filePath).readAsBytes(),
                );
                if (outputFile == null) {
                  EasyLoading.showSuccess('Save to Disk successfully');
                }
              },
              child: const Text('Save to Disk'),
            ),
          ],
        );
      case FileStatus.downloading:
        return FilledButton(
          onPressed: () => EasyLoading.showToast('Downloading'),
          child: const Text('Downloading'),
        );
      default:
        return FilledButton(
          onPressed: () {
            EasyLoading.showToast('Start downloading');
            _startDownload();
          },
          child: const Text('Download File'),
        );
    }
  }
}
