import 'dart:io'
    show Directory, File, FileStat, FileSystemEntity, FileSystemEntityType;

import 'package:app/page/log_viewer.dart';
import 'package:app/service/file.service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';

import 'package:share_plus/share_plus.dart';

class FileExplorerPage extends StatefulWidget {
  final Directory dir;
  final bool showDeleteButton;
  const FileExplorerPage(
      {super.key, required this.dir, this.showDeleteButton = false});

  @override
  _FileExplorerPageState createState() => _FileExplorerPageState();
}

class _FileExplorerPageState extends State<FileExplorerPage> {
  List<FileSystemEntity> _files = [];
  // final int _totalFileSize = 0;
  late String folderName;
  @override
  void initState() {
    folderName = widget.dir.path.split('/').last;
    if (folderName.startsWith('com.keychat')) {
      folderName = 'Files Explorer';
    }
    super.initState();
    _getFilesAndFolders(widget.dir);
  }

  void _getFilesAndFolders(Directory dir) {
    List<FileSystemEntity> entities = dir.listSync();

    // for (Directory subdir in entities.whereType<Directory>()) {
    //   _getFilesAndFolders(subdir);
    // }
    setState(() {
      var list = entities.toList();

      list.sort((a, b) {
        if (a is Directory && b is File) {
          return -1;
        }
        if (a is File && b is Directory) {
          return 1;
        }
        return a.path.compareTo(b.path);
      });
      _files = list;
      // _dirs = entities.whereType<Directory>().toList();
    });

    // _calculateTotalFileSize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(folderName),
        actions: widget.showDeleteButton
            ? [
                IconButton(
                    onPressed: () async {
                      Get.dialog(CupertinoAlertDialog(
                        title: const Text('Delete All'),
                        content: const Text(
                            'Are you sure you want to delete all log files?'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Get.back();
                            },
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () async {
                              await widget.dir.delete(recursive: true);
                              EasyLoading.showSuccess('Deleted');
                              Directory(widget.dir.path)
                                  .create(recursive: true);
                              Get.back();
                              Get.back();
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ));
                    },
                    icon: const Icon(Icons.delete)),
              ]
            : GetPlatform.isDesktop
                ? [
                    TextButton(
                      onPressed: () {
                        OpenFilex.open(widget.dir.path);
                      },
                      child: const Text('Open'),
                    )
                  ]
                : null,
      ),
      body: ListView.builder(
        itemCount: _files.length,
        itemBuilder: (BuildContext context, int index) {
          FileSystemEntity file = _files[index];
          FileStat stat = file.statSync();

          if ((file.path.endsWith('.txt') || file.path.endsWith('.log')) &&
              file is File) {
            return ListTile(
              leading: const Icon(CupertinoIcons.doc),
              title: Text(file.path.substring(widget.dir.path.length + 1)),
              subtitle:
                  Text(FileService.instance.getFileSizeDisplay(stat.size)),
              trailing: _getDownloadButton(file),
              dense: true,
              onTap: () {
                Get.to(() => LogViewer(path: file.path));
              },
              onLongPress: () {
                showClickDialog(file);
              },
            );
          }
          bool isDirectory = stat.type == FileSystemEntityType.directory;
          return ListTile(
            onLongPress: () {
              if (isDirectory && file.path.contains('logs')) {
                showClickDialog(file);
              }
            },
            dense: true,
            onTap: () {
              if (isDirectory) {
                bool isLogFile =
                    file.path.endsWith('logs') || file.path.endsWith('errors');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => FileExplorerPage(
                            key: Key(file.path),
                            dir: file as Directory,
                            showDeleteButton: isLogFile,
                          )),
                );
                return;
              }
              if (file.path.contains('.')) {
                Set suffixs = {
                  'db',
                  'db3',
                  '.isar',
                  '.lock',
                  'db-wal',
                  'db-shm'
                };
                String suffix = file.path.split('.').last;
                if (suffixs.contains(suffix)) {
                  return;
                }
              }

              showClickDialog(file);
            },
            leading: isDirectory
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: Image.asset('assets/images/file.png',
                        fit: BoxFit.contain))
                : Icon(CupertinoIcons.doc),
            title: Text(file.path.substring(widget.dir.path.length + 1)),
            subtitle: isDirectory
                ? null
                : Text(FileService.instance.getFileSizeDisplay(stat.size)),
            trailing: isDirectory ? null : _getDownloadButton(file),
          );
        },
      ),
    );
  }

  IconButton _getDownloadButton(FileSystemEntity sourceFile) {
    return IconButton(
        onPressed: () async {
          if (GetPlatform.isDesktop) {
            String dir =
                sourceFile.path.substring(0, sourceFile.path.lastIndexOf('/'));
            OpenFilex.open(dir);
            return;
          }

          await SharePlus.instance.share(ShareParams(
              files: [XFile(sourceFile.path)],
              previewThumbnail: XFile(sourceFile.path),
              subject: FileService.instance
                  .getDisplayFileName(sourceFile.path.split('/').last)));
        },
        icon: const Icon(CupertinoIcons.share));
  }

  void showClickDialog(FileSystemEntity file) {
    Get.dialog(CupertinoAlertDialog(
      title: const Text('Delete'),
      content: const Text('Are you sure you want to delete this file?'),
      actions: [
        CupertinoDialogAction(
          child: const Text('Cancel'),
          onPressed: () {
            Get.back();
          },
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () async {
            await file.delete(recursive: file is Directory);
            EasyLoading.showSuccess('Deleted');
            Get.back();
            _getFilesAndFolders(widget.dir);
          },
          child: const Text('Delete'),
        ),
      ],
    ));
  }
}
