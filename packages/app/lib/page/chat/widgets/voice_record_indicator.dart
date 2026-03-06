import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/service/audio_message.service.dart';

/// Recording overlay shown in place of the text field during voice recording.
///
/// Displays elapsed time and a "slide left to cancel" hint.
class VoiceRecordIndicator extends StatelessWidget {
  const VoiceRecordIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = AudioMessageService.instance;
    return Obx(() {
      final secs = svc.recordingSeconds.value;
      final minutes = (secs ~/ 60).toString().padLeft(2, '0');
      final seconds = (secs % 60).toString().padLeft(2, '0');

      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.circle, color: Colors.red, size: 10),
            const SizedBox(width: 8),
            Text(
              '$minutes:$seconds',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
            const Spacer(),
            Text(
              '\u2190 Slide to cancel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      );
    });
  }
}
