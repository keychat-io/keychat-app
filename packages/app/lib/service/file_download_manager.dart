import 'package:flutter/foundation.dart';
import 'package:keychat/app.dart';
import 'package:keychat/service/file.service.dart';

/// Tracks active file downloads with real-time progress.
///
/// Provides deduplication (same message won't download twice) and
/// a ValueNotifier per download so widgets can listen for progress.
/// Progress is transient (memory only) — persisted state lives in
/// Message.realMessage via FileService.downloadForMessage.
class FileDownloadManager {
  FileDownloadManager._();
  static final FileDownloadManager instance = FileDownloadManager._();

  final Map<int, ValueNotifier<double>> _active = {};

  /// Returns the progress notifier for [messageId], or null if not downloading.
  ValueNotifier<double>? getProgress(int messageId) => _active[messageId];

  /// Whether [messageId] has an active download in progress.
  bool isDownloading(int messageId) => _active.containsKey(messageId);

  /// Starts downloading the file for [message].
  ///
  /// Returns the progress ValueNotifier (0.0–1.0). If already downloading,
  /// returns the existing notifier (dedup).
  /// [downloadForMessage] handles DB writes and page refresh internally.
  ValueNotifier<double> startDownload(Message message, MsgFileInfo mfi) {
    if (_active.containsKey(message.id)) {
      return _active[message.id]!;
    }

    final notifier = ValueNotifier<double>(0);
    _active[message.id] = notifier;
    _execute(message, mfi, notifier);
    return notifier;
  }

  Future<void> _execute(
    Message message,
    MsgFileInfo mfi,
    ValueNotifier<double> notifier,
  ) async {
    try {
      await FileService.instance.downloadForMessage(
        message,
        mfi,
        onReceiveProgress: (int count, int total) {
          if (total > 0 && _active.containsKey(message.id)) {
            notifier.value = count / total;
          }
        },
      );
    } finally {
      _active.remove(message.id);
    }
  }
}
