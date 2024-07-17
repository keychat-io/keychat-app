import 'dart:io' show File;

import 'package:app/controller/setting.controller.dart';
import 'package:app/models/embedded/msg_file_info.dart';
import 'package:app/models/message.dart';
import 'package:app/page/components.dart';
import 'package:app/service/file_util.dart';
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
    fileSize = FileUtils.getFileSizeDisplay(msgFileInfo.size);
    super.initState();

    _init(widget.mfi);
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
          title: const Text(''),
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
        body: Center(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.doc_chart_fill,
                        size: 58,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5)),
                    const SizedBox(
                      height: 10,
                    ),
                    Text(
                      msgFileInfo.localPath == null
                          ? msgFileInfo.fileName
                          : msgFileInfo.localPath!.split('/').last,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Text(
                        'Size: ${FileUtils.getFileSizeDisplay(msgFileInfo.size)}'),
                    textSmallGray(
                        context, 'Encrypted by AES-256-CTR with one-time key'),
                    if (downloadProgress > 0 && downloadProgress < 100)
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 20, bottom: 10, left: 16, right: 16),
                        child: LinearProgressIndicator(
                          value: downloadProgress / 100,
                        ),
                      ),
                    const SizedBox(
                      height: 50,
                    ),
                    getStatusButton(),
                    if (fileStatus == FileStatus.decryptSuccess &&
                        msgFileInfo.localPath != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 30),
                          child: OutlinedButton.icon(
                              onPressed: () async {
                                String filePath =
                                    '${Get.find<SettingController>().appFolder.path}${msgFileInfo.localPath!}';

                                await Share.shareXFiles([XFile(filePath)],
                                    subject: FileUtils.getDisplayFileName(
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
        return FilledButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              String filePath =
                  '${Get.find<SettingController>().appFolder.path}${msgFileInfo.localPath!}';
              if (GetPlatform.isDesktop) {
                String dir = filePath.substring(0, filePath.lastIndexOf('/'));
                OpenFilex.open(dir);
              } else {
                OpenFilex.open(filePath);
              }
            },
            child: const Text('Open in Other APP'));
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
              FileUtils.downloadForMessage(widget.message, msgFileInfo,
                  callback: _init, onReceiveProgress: (int count, int total) {
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
