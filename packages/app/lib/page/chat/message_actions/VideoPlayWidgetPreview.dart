import 'dart:io' show File;

import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

class VideoPlayPreviewWidget extends StatefulWidget {
  final String filePath;
  final File thumbnailFile;
  const VideoPlayPreviewWidget(this.thumbnailFile, this.filePath, {super.key});

  @override
  _VideoPlayWidgetState createState() => _VideoPlayWidgetState();
}

class _VideoPlayWidgetState extends State<VideoPlayPreviewWidget> {
  VideoPlayerController? _controller;
  bool isPause = false;
  @override
  void initState() {
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        // _controller!.play();
        setState(() {});
      }).catchError((e, s) {
        logger.e(e.toString(), error: e, stackTrace: s);
      });
    _controller!.addListener(() {
      if (_controller!.value.isCompleted) {
        setState(() {
          isPause = true;
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: GestureDetector(
            onTap: () {
              if (_controller == null) return;
              bool isPlaying = _controller!.value.isPlaying;
              if (isPlaying) {
                _controller!.pause();
                setState(() {
                  isPause = true;
                });
              }
            },
            onVerticalDragUpdate: (DragUpdateDetails details) {
              double dy = details.delta.dy;
              if (dy > 10) {
                _controller?.pause();
                Get.back();
              }
            },
            onDoubleTap: () {
              _controller?.pause();
              Get.back();
            },
            child:
                _controller == null || _controller!.value.isInitialized == false
                    ? Stack(
                        children: <Widget>[
                          Image.file(widget.thumbnailFile, fit: BoxFit.contain),
                        ],
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: <Widget>[
                                VideoPlayer(_controller!),
                                ClosedCaption(
                                    text: _controller!.value.caption.text),
                                VideoProgressIndicator(_controller!,
                                    allowScrubbing: true),
                              ],
                            ),
                          ),
                          if (isPause)
                            Positioned(
                              child: CircleAvatar(
                                  radius: 28,
                                  child: IconButton(
                                    onPressed: () {
                                      _controller!.play();
                                      setState(() {
                                        isPause = false;
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.play_arrow,
                                      size: 28,
                                    ),
                                  )),
                            ),
                        ],
                      )));
  }
}
