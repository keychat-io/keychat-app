import 'dart:io' show File;

import 'package:app/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

class VideoPlayWidget extends StatefulWidget {
  const VideoPlayWidget(this.thumbnailFile, this.filePath, this.autoPlay,
      {super.key});
  final String filePath;
  final File thumbnailFile;
  final bool autoPlay;

  @override
  _VideoPlayWidgetState createState() => _VideoPlayWidgetState();
}

class _VideoPlayWidgetState extends State<VideoPlayWidget> {
  VideoPlayerController? _controller;
  bool isPause = false;
  @override
  void initState() {
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        if (widget.autoPlay) {
          _controller!.play();
        }
        setState(() {
          isPause = !widget.autoPlay;
        });
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
    return Scaffold(
        body: Center(
      child: GestureDetector(
          onTap: () {
            if (_controller == null) return;
            final isPlaying = _controller!.value.isPlaying;
            if (isPlaying) {
              _controller!.pause();
              setState(() {
                isPause = true;
              });
            }
          },
          onVerticalDragUpdate: (DragUpdateDetails details) {
            final dy = details.delta.dy;
            if (dy > 10) {
              _controller?.pause();
              Get.back<void>();
            }
          },
          onDoubleTap: () {
            _controller?.pause();
            Get.back<void>();
          },
          child: _controller == null ||
                  _controller!.value.isInitialized == false
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
                          ClosedCaption(text: _controller!.value.caption.text),
                          VideoProgressIndicator(_controller!,
                              allowScrubbing: true),
                        ],
                      ),
                    ),
                    if (isPause)
                      Positioned(
                        child: CircleAvatar(
                            radius: 32,
                            child: IconButton(
                              onPressed: () {
                                _controller!.play();
                                setState(() {
                                  isPause = false;
                                });
                              },
                              icon: const Icon(
                                Icons.play_arrow,
                                size: 32,
                              ),
                            )),
                      ),
                  ],
                )),
    ));
  }
}
