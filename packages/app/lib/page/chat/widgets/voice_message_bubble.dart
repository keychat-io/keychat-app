import 'dart:async';
import 'dart:convert' show base64Decode;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:keychat/models/message.dart';

class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({
    // required this.audioUrl,
    required this.message,
    super.key,
    this.duration,
    this.waveformBase64,
    this.isFromMe = false,
  });
  final Message message;
  String get audioUrl => message.content; // TODOlocal file path or remote URL
  final int? duration; // seconds
  final String? waveformBase64;
  final bool isFromMe;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackSpeed = 1;
  List<double> _waveformData = [];

  @override
  void initState() {
    super.initState();
    _decodeWaveform();
    _initPlayer();
  }

  void _decodeWaveform() {
    if (widget.waveformBase64 == null || widget.waveformBase64!.isEmpty) {
      _waveformData = List.filled(50, 0.3); // default flat waveform
      return;
    }

    try {
      final bytes = base64Decode(widget.waveformBase64!);
      final samples = <double>[];
      var bitPos = 0;

      while (bitPos + 5 <= bytes.length * 8) {
        var value = 0;
        for (var bit = 0; bit < 5; bit++) {
          if (bytes[(bitPos + bit) ~/ 8] & (1 << ((bitPos + bit) % 8)) != 0) {
            value |= 1 << bit;
          }
        }
        samples.add(value / 31.0);
        bitPos += 5;
      }

      _waveformData = samples.isEmpty ? List.filled(50, 0.3) : samples;
    } catch (_) {
      _waveformData = List.filled(50, 0.3);
    }
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.audioUrl.startsWith('/') ||
          widget.audioUrl.startsWith('file:')) {
        await _player.setFilePath(widget.audioUrl.replaceFirst('file://', ''));
      } else {
        await _player.setUrl(widget.audioUrl);
      }

      _player.durationStream.listen((d) {
        if (d != null && mounted) setState(() => _totalDuration = d);
      });

      _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });

      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
          if (state.processingState == ProcessingState.completed) {
            _player.seek(Duration.zero);
            _player.pause();
          }
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _cycleSpeed() {
    final speeds = [1.0, 1.5, 2.0];
    final idx = speeds.indexOf(_playbackSpeed);
    _playbackSpeed = speeds[(idx + 1) % speeds.length];
    _player.setSpeed(_playbackSpeed);
    setState(() {});
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final displayDuration = _totalDuration > Duration.zero
        ? _totalDuration
        : Duration(seconds: widget.duration ?? 0);
    final progress = displayDuration.inMilliseconds > 0
        ? _position.inMilliseconds / displayDuration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: widget.isFromMe
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Waveform + duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform visualization
                SizedBox(
                  height: 28,
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      data: _waveformData,
                      progress: progress.clamp(0.0, 1.0),
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.4),
                    ),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: 2),
                // Duration + speed
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPlaying
                          ? _formatDuration(_position)
                          : _formatDuration(displayDuration),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_isPlaying)
                      GestureDetector(
                        onTap: _cycleSpeed,
                        child: Text(
                          '${_playbackSpeed}x',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.data,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> data;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final barWidth = size.width / data.length;
    final maxHeight = size.height;
    final progressX = size.width * progress;

    for (var i = 0; i < data.length; i++) {
      final x = i * barWidth;
      final barHeight = (data[i] * maxHeight).clamp(2.0, maxHeight);
      final y = (maxHeight - barHeight) / 2;

      final paint = Paint()
        ..color = x < progressX ? activeColor : inactiveColor
        ..strokeCap = StrokeCap.round;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth * 0.6, barHeight),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.data != data;
  }
}
