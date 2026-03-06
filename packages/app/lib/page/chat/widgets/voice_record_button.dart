import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/service/audio_message.service.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

/// Mic button for the chat input bar.
///
/// Long-press starts recording, slide left to cancel, release to send.
class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({required this.room, super.key});

  final Room room;

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  final AudioMessageService _svc = AudioMessageService.instance;

  // Track horizontal drag for cancel gesture
  double _startDx = 0;
  bool _isCancelled = false;
  static const double _cancelThreshold = 100.0;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isRecording = _svc.isRecording.value;

      return GestureDetector(
        onLongPressStart: (details) async {
          _startDx = details.globalPosition.dx;
          _isCancelled = false;
          final started = await _svc.startRecording(widget.room);
          if (!started && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Microphone permission required'),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: openAppSettings,
                ),
              ),
            );
          }
        },
        onLongPressMoveUpdate: (details) {
          final dx = _startDx - details.globalPosition.dx;
          if (dx > _cancelThreshold && !_isCancelled) {
            _isCancelled = true;
            _svc.cancelRecording();
          }
        },
        onLongPressEnd: (_) async {
          if (!_isCancelled && _svc.isRecording.value) {
            await _svc.stopAndSend();
          }
          _isCancelled = false;
        },
        onLongPressCancel: () {
          _svc.cancelRecording();
          _isCancelled = false;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(4),
          decoration: isRecording
              ? BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                )
              : null,
          child: Icon(
            isRecording ? Icons.mic : Icons.mic_none_outlined,
            size: 28,
            color: isRecording ? Colors.red : null,
          ),
        ),
      );
    });
  }
}
