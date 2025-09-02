import 'dart:io' show File, Directory, FileSystemEntity;

import 'package:app/models/message.dart';
import 'package:app/models/room.dart';
import 'package:app/page/widgets/image_slide_widget.dart';
import 'package:app/service/file.service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class ChatMediaFilesPage extends StatefulWidget {
  final Room room;
  const ChatMediaFilesPage(this.room, {super.key});

  @override
  _ChatMediaFilesPageState createState() => _ChatMediaFilesPageState();
}

class _ChatMediaFilesPageState extends State<ChatMediaFilesPage> {
  List<File> media = [];
  @override
  void initState() {
    super.initState();
    loadMedia();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.room.getRoomName()),
          actions: [
            IconButton(
                onPressed: () {
                  Get.dialog(
                      CupertinoAlertDialog(
                        title: const Text('Delete All Media?'),
                        content: const Text(
                            'Are you sure to delete all media in this chat?'),
                        actions: [
                          CupertinoDialogAction(
                              onPressed: () {
                                Get.back();
                              },
                              child: const Text('Cancel')),
                          CupertinoDialogAction(
                              isDestructiveAction: true,
                              onPressed: () async {
                                EasyLoading.show(status: 'Deleting...');
                                try {
                                  String directory = await FileService.instance
                                      .getRoomFolder(
                                          identityId: widget.room.identityId,
                                          roomId: widget.room.id);
                                  await Directory(directory)
                                      .delete(recursive: true);
                                  EasyLoading.dismiss();
                                  EasyLoading.showSuccess('Deleted');
                                } catch (e) {
                                  EasyLoading.dismiss();
                                  EasyLoading.showError(e.toString());
                                }

                                Get.back();
                                Get.back();
                              },
                              child: const Text('Delete')),
                        ],
                      ),
                      barrierDismissible: false);
                },
                icon: const Icon(Icons.delete))
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Media'),
              Tab(text: 'Files'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            media.isEmpty
                ? const Center(
                    child: Icon(Icons.inbox, size: 60, color: Colors.grey),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(10.0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: media.length,
                    itemBuilder: (context, index) {
                      File file = media[index];
                      late Widget child;
                      if (FileService.instance.isImageFile(file.path)) {
                        child = GestureDetector(
                            onTap: () {
                              _onTap(index);
                            },
                            child: FileService.instance.getImageView(file));
                      } else if (FileService.instance.isVideoFile(file.path)) {
                        child = FutureBuilder(
                            future: FileService.instance
                                .getOrCreateThumbForVideo(file.path),
                            builder: (context, snapshot) {
                              if (snapshot.data != null) {
                                File thumbnailFile = snapshot.data as File;
                                return GestureDetector(
                                    onTap: () {
                                      _onTap(index, thumbnailFile);
                                    },
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: <Widget>[
                                        ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: SizedBox(
                                                width: 150,
                                                child: Image.file(thumbnailFile,
                                                    fit: BoxFit.contain))),
                                        Positioned(
                                          child: CircleAvatar(
                                              radius: 20,
                                              backgroundColor: Colors.grey
                                                  .withValues(alpha: 0.8),
                                              child: IconButton(
                                                onPressed: () {},
                                                icon: const Icon(
                                                  Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              )),
                                        ),
                                      ],
                                    ));
                              }
                              return const Text('Video File');
                            });
                      }

                      return Container(
                          width: 90,
                          height: 150,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          child: child);
                    },
                  ),
            FutureBuilder<List<FileSystemEntity>>(
              future: _fetchFileData(),
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else {
                    List<FileSystemEntity> files = snapshot.data;
                    return media.isEmpty
                        ? const Center(
                            child:
                                Icon(Icons.inbox, size: 60, color: Colors.grey),
                          )
                        : ListView.builder(
                            itemCount: files.length,
                            itemBuilder: (context, index) {
                              String filePath = files[index].path;
                              var file = File(filePath);
                              var stat = file.statSync();
                              String fileFullName = filePath.split('/').last;
                              String suffix = 'File';
                              if (fileFullName.contains('.')) {
                                suffix = fileFullName.split('.').last;
                              }
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(suffix.toUpperCase()),
                                ),
                                title: Text(file.path.split('/').last),
                                subtitle: Text(
                                    '${FileService.instance.getFileSizeDisplay(stat.size)}, ${DateFormat('yyyy-MM-dd HH:mm').format(stat.changed)}'),
                                onTap: () {
                                  try {
                                    if (GetPlatform.isDesktop) {
                                      String dir = filePath.substring(
                                          0, filePath.lastIndexOf('/'));
                                      OpenFilex.open(dir);
                                    } else {
                                      OpenFilex.open(filePath);
                                    }
                                  } catch (e) {
                                    SharePlus.instance.share(ShareParams(
                                        previewThumbnail: XFile(filePath),
                                        subject: FileService.instance
                                            .getDisplayFileName(fileFullName)));
                                  }
                                },
                              );
                            },
                          );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void loadMedia() async {
    List<File> files = await FileService.instance
        .getRoomImageAndVideo(widget.room.identityId, widget.room.id);
    setState(() {
      media = files;
    });
    // String base = await FileService.instance.getRoomFolder(
    //   identityId: cc.room.identityId,
    //   roomId: cc.room.id);
  }

  void _onTap(int index, [File? thumbnailFile]) {
    Get.to(
        () => SlidesImageViewWidget(
              files: media,
              file: thumbnailFile,
              selected: media[index],
            ),
        transition: Transition.zoom,
        fullscreenDialog: true);
  }

  Future<List<FileSystemEntity>> _fetchFileData() async {
    String base = await FileService.instance.getRoomFolder(
        identityId: widget.room.identityId,
        roomId: widget.room.id,
        type: MessageMediaType.file);
    Directory directory = Directory(base);
    return directory.listSync();
  }
}
