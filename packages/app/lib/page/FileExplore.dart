import 'dart:io'
    show Directory, File, FileStat, FileSystemEntity, FileSystemEntityType;

import 'package:app/page/log_viewer.dart';
import 'package:app/service/file_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

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

  @override
  void initState() {
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
        title: const Text('File Explorer'),
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
            : null,
      ),
      body: ListView.builder(
        itemCount: _files.length,
        itemBuilder: (BuildContext context, int index) {
          FileSystemEntity file = _files[index];
          FileStat stat = file.statSync();

          if (file.path.endsWith('.txt') && file is File) {
            return ListTile(
              leading: const Icon(
                Icons.note,
                color: Colors.black,
              ),
              title: Text(file.path.substring(widget.dir.path.length + 1)),
              subtitle: Text(FileUtils.getFileSizeDisplay(stat.size)),
              trailing: _getDownloadButton(file),
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
            onTap: () {
              if (isDirectory) {
                bool isLogFile = file.path.endsWith('logs');
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
              if (file.path.endsWith('.isar') ||
                  file.path.endsWith('.lock') ||
                  file.path.endsWith('.db')) {
                return;
              }
              showClickDialog(file);
            },
            leading: Icon(
              isDirectory ? Icons.file_copy_sharp : Icons.storage,
              color: isDirectory ? Colors.blue : Colors.black,
            ),
            title: Text(file.path.substring(widget.dir.path.length + 1)),
            subtitle: isDirectory
                ? null
                : Text(FileUtils.getFileSizeDisplay(stat.size)),
            trailing: isDirectory ? null : _getDownloadButton(file),
          );
        },
      ),
    );
  }

  _getDownloadButton(FileSystemEntity sourceFile) {
    return IconButton(
        onPressed: () async {
          Share.shareXFiles([XFile(sourceFile.path)],
              subject: FileUtils.getDisplayFileName(
                  sourceFile.path.split('/').last));

          // PermissionStatus permissionStatus =
          //     await Utils.getStoragePermission();
          // if (!permissionStatus.isGranted) {
          //   EasyLoading.showError('Permission denied',
          //       duration: const Duration(seconds: 2));
          //   return;
          // }

          // String filename =
          //     sourceFile.path.substring(widget.dir.path.length + 1);
          // try {
          //   if (!await FlutterFileDialog.isPickDirectorySupported()) {
          //     EasyLoading.showToast("Picking directory not supported");
          //     return;
          //   }

          //   final pickedDirectory = await FlutterFileDialog.pickDirectory();

          //   if (pickedDirectory == null) return;
          //   String mimeType = lookupMimeType(sourceFile.path) ?? "text/plain";

          //   final filePath = await FlutterFileDialog.saveFileToDirectory(
          //     directory: pickedDirectory,
          //     data: (sourceFile as File).readAsBytesSync(),
          //     mimeType: mimeType,
          //     fileName: filename,
          //     replace: true,
          //   );
          //   logger.d('saved to $filePath');
          //   EasyLoading.showSuccess('Downloaded');
          // } catch (e, s) {
          //   logger.e(e.toString(), error: e, stackTrace: s);
          //   EasyLoading.showError('Failed to download',
          //       duration: const Duration(seconds: 2));
          // }
        },
        icon: const Icon(CupertinoIcons.share));
  }

  showClickDialog(FileSystemEntity file) {
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
