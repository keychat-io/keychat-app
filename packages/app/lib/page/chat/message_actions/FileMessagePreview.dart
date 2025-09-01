import 'dart:io' show File;

import 'package:app/controller/setting.controller.dart';
import 'package:app/models/embedded/msg_file_info.dart';
import 'package:app/models/message.dart';
import 'package:app/page/components.dart';
import 'package:app/service/file.service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class FileMessagePreview extends StatefulWidget {
  final Message message;
  final MsgFileInfo mfi;
  const FileMessagePreview(this.message, this.mfi, {super.key});

  @override
  _FileMessagePreviewState createState() => _FileMessagePreviewState();
}

class _FileMessagePreviewState extends State<FileMessagePreview> {
  FileStatus fileStatus = FileStatus.init;
  late MsgFileInfo msgFileInfo;
  late String fileSize;
  double downloadProgress = 100;

  @override
  void initState() {
    msgFileInfo = widget.mfi;
    fileSize = FileService.instance.getFileSizeDisplay(msgFileInfo.size);
    super.initState();

    _init(widget.mfi);
  }

  void _init(MsgFileInfo mfi) {
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
      String filePath =
          '${Get.find<SettingController>().appFolder.path}${mfi.localPath!}';
      bool fileExists = File(filePath).existsSync();

      if (fileExists == false) {
        setState(() {
          fileStatus = FileStatus.init;
          msgFileInfo = mfi;
        });
        return;
      }

      setState(() {
        fileStatus = FileStatus.decryptSuccess;
        msgFileInfo = mfi;
      });
    }
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
                    String filePath =
                        '${Get.find<SettingController>().appFolder.path}${msgFileInfo.localPath!}';
                    bool fileExists = File(filePath).existsSync();

                    if (fileExists) {
                      await File(filePath).delete();
                    }
                    EasyLoading.showToast('File deleted');
                    _init(msgFileInfo);
                  },
                  icon: const Icon(CupertinoIcons.delete))
          ],
        ),
        body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(msgFileInfo.fileName,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Text(
                    'Size: ${FileService.instance.getFileSizeDisplay(msgFileInfo.size)}'),
                textSmallGray(
                    context, 'Encrypted by AES-256-CTR with one-time key'),
                if (downloadProgress > 0 && downloadProgress < 100)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: LinearProgressIndicator(
                      value: downloadProgress / 100,
                    ),
                  ),
                const SizedBox(height: 16),
                getStatusButton(),
                if (fileStatus == FileStatus.decryptSuccess &&
                    msgFileInfo.localPath != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                          onPressed: () async {
                            String filePath =
                                '${Get.find<SettingController>().appFolder.path}${msgFileInfo.localPath!}';

                            await Share.shareXFiles([XFile(filePath)],
                                subject: FileService.instance
                                    .getDisplayFileName(
                                        msgFileInfo.localPath!));
                          },
                          icon: const Icon(CupertinoIcons.share),
                          label: const Text('More'))),
              ],
            ))));
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
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    String filePath =
                        '${Get.find<SettingController>().appFolder.path}${msgFileInfo.localPath!}';
                    if (GetPlatform.isDesktop) {
                      String dir =
                          filePath.substring(0, filePath.lastIndexOf('/'));
                      OpenFilex.open(dir);
                    } else {
                      OpenFilex.open(filePath);
                    }
                  },
                  child: Text(
                      GetPlatform.isDesktop
                          ? 'View in Finder'
                          : 'Open in Other App',
                      style: TextStyle(color: Colors.white))),
              OutlinedButton(
                  onPressed: () async {
                    String filePath =
                        '${Get.find<SettingController>().appFolder.path}${msgFileInfo.localPath!}';
                    String fileName = msgFileInfo.localPath!.split('/').last;
                    String? outputFile = await FilePicker.platform.saveFile(
                      dialogTitle: 'Please select an output path:',
                      fileName: fileName,
                      bytes: await File(filePath).readAsBytes(),
                    );

                    if (outputFile == null) {
                      EasyLoading.showSuccess('Save to Disk successfully');
                    }
                  },
                  child: const Text('Save to Disk'))
            ]);
      case FileStatus.downloading:
        return FilledButton(
            onPressed: () {
              EasyLoading.showToast('Downloading');
            },
            child: const Text('Downloading'));
      default:
        return FilledButton(
            onPressed: () {
              EasyLoading.showToast('Start downloading');
              FileService.instance.downloadForMessage(
                  widget.message, msgFileInfo, callback: _init,
                  onReceiveProgress: (int count, int total) {
                if (count == total) {
                  EasyLoading.showToast('Download successfully');
                }
                setState(() {
                  downloadProgress = (count / total) * 100;
                });
              });
            },
            child: const Text('Download File'));
    }
  }
}
