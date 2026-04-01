import 'dart:convert' show jsonDecode;
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/models/embedded/msg_file_info.dart';
import 'package:keychat/models/message.dart';
import 'package:keychat/service/audio_message.service.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/utils.dart';

/// Renders a voice message bubble with play/pause button and progress bar.
class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble(this.message, this.errorCallback, {super.key});

  final Message message;
  final Widget Function({Widget? child, String? text}) errorCallback;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  MsgFileInfo? _mfi;
  bool _decodeError = false;

  @override
  void initState() {
    super.initState();
    try {
      if (widget.message.realMessage == null) {
        throw Exception('realMessage is null');
      }
      _mfi = MsgFileInfo.fromJson(
        jsonDecode(widget.message.realMessage!) as Map<String, dynamic>,
      );
    } catch (_) {
      _decodeError = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_decodeError || _mfi == null) {
      return widget.errorCallback(text: '[Voice message error]');
    }

    final mfi = _mfi!;
    final svc = AudioMessageService.instance;
    final totalSecs = mfi.audioDuration ?? 0;
    final totalDuration = Duration(seconds: totalSecs);

    return Obx(() {
      final isThisPlaying =
          svc.currentPlayingMsgId.value == widget.message.msgid;
      final position =
          isThisPlaying ? svc.playbackPosition.value : Duration.zero;
      final duration =
          isThisPlaying && svc.playbackDuration.value > Duration.zero
              ? svc.playbackDuration.value
              : totalDuration;
      final progress = duration.inMilliseconds > 0
          ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

      return SizedBox(
        width: 200,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _onTap(mfi),
              child: Icon(
                isThisPlaying && svc.isPlaying.value
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(isThisPlaying ? position : duration),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _onTap(MsgFileInfo mfi) async {
    final svc = AudioMessageService.instance;

    // If playing this message, pause
    if (svc.currentPlayingMsgId.value == widget.message.msgid &&
        svc.isPlaying.value) {
      await svc.pause();
      return;
    }

    // Check if file needs to be downloaded first
    if (mfi.localPath == null) {
      await _downloadAudio(mfi);
      return;
    }
    final filePath = '${Utils.appFolder.path}${mfi.localPath}';
    if (!File(filePath).existsSync()) {
      await _downloadAudio(mfi);
      return;
    }

    await svc.play(widget.message);
  }

  /// Download and decrypt the audio file, then update local state.
  Future<void> _downloadAudio(MsgFileInfo mfi) async {
    try {
      await FileService.instance.downloadForMessage(
        widget.message,
        mfi,
        callback: (updatedMfi) {
          if (mounted) {
            setState(() {
              _mfi = updatedMfi;
            });
          }
        },
      );
      // After download, update mfi from the message's realMessage
      if (widget.message.realMessage != null) {
        final updated = MsgFileInfo.fromJson(
          jsonDecode(widget.message.realMessage!) as Map<String, dynamic>,
        );
        if (mounted) {
          setState(() {
            _mfi = updated;
          });
        }
      }
    } catch (e) {
      // Download failed, user can tap again to retry
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
