import 'dart:io' show File;

import 'package:app/page/chat/message_actions/VideoPlayWidget.dart';
import 'package:app/service/file.service.dart';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';

import 'package:share_plus/share_plus.dart';

class SlidesImageViewWidget extends StatefulWidget {
  final File selected;
  final File? file;
  final List<File> files;

  const SlidesImageViewWidget(
      {super.key, required this.files, required this.selected, this.file});
  @override
  _NewPageState createState() => _NewPageState();
}

class _NewPageState extends State<SlidesImageViewWidget> {
  int _currentIndex = 0;
  int initialPage = 0;
  List _files = [];
  @override
  void initState() {
    _files = widget.files.isEmpty ? [widget.selected] : widget.files;

    int index =
        _files.indexWhere((element) => element.path == widget.selected.path);
    if (index == -1) {
      _files = [widget.selected];
    }
    setState(() {
      initialPage = index == -1 ? 0 : index;
      _currentIndex = initialPage;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.initState();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
      floatingActionButton: GestureDetector(
          onTap: Get.back,
          child: Text('${_currentIndex + 1} / ${_files.length}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ))),
      body: CarouselSlider(
        options: CarouselOptions(
            initialPage: initialPage,
            onPageChanged: (index, reason) => {
                  setState(() {
                    _currentIndex = index;
                  })
                },
            height: Get.height,
            viewportFraction: 1.0,
            enlargeCenterPage: true,
            enableInfiniteScroll: false),
        items: _files.map((file) {
          return Builder(builder: (BuildContext context) {
            return _getStackWidget(file);
          });
        }).toList(),
      ),
    );
  }

  Widget _getStackWidget(File file) {
    bool isImageFile = FileService.instance.isImageFile(file.path);
    return Stack(key: Key(file.path), children: <Widget>[
      if (isImageFile)
        GestureDetector(
            onVerticalDragUpdate: (DragUpdateDetails details) {
              double dy = details.delta.dy;
              if (dy > 20) {
                Get.back();
              }
            },
            child: PhotoView.customChild(
              child: Center(child: Image.file(file, fit: BoxFit.contain)),
            )),
      if (FileService.instance.isVideoFile(file.path))
        FutureBuilder(
            key: Key(file.path),
            future: FileService.instance.getOrCreateThumbForVideo(file.path),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                bool selected = widget.selected.path == file.path;
                return VideoPlayWidget(
                    snapshot.data as File, file.path, selected);
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            }),
      if (GetPlatform.isMobile)
        Positioned(
          right: 5,
          bottom: 20,
          child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(
                  CupertinoIcons.share,
                  color: Colors.white,
                ),
                onPressed: () {
                  Share.shareXFiles([XFile(_files[_currentIndex].path)]);
                },
              )),
        ),
      Positioned(
          left: 5,
          bottom: 20,
          child: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.black54,
            child: IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
              ),
              onPressed: () {
                Get.back();
              },
            ),
          )),
    ]);
  }
}
