import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:keychat/app.dart';
import 'package:keychat/service/file.service.dart';

/// Tracks active file downloads with real-time progress.
///
/// Provides deduplication (same message won't download twice) and
/// a ValueNotifier per download so widgets can listen for progress.
/// Progress is transient (memory only) — persisted state lives in
/// Message.realMessage via FileService.downloadForMessage.
///
/// Notifier values: 0.0–1.0 = progress, -1.0 = failed.
/// After completion/failure, the notifier fires one last time before
/// being removed from the active map, so listeners always get notified.
class FileDownloadManager {
  FileDownloadManager._();
  static final FileDownloadManager instance = FileDownloadManager._();

  /// Timeout for stale "downloading" states in widgets.
  static const staleTimeout = Duration(seconds: 120);

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
    // Schedule on a microtask so the caller receives the notifier first and
    // can attach listeners before any terminal value (1.0 / -1.0) is set —
    // matters when _execute would otherwise throw synchronously before its
    // first await.
    unawaited(Future.microtask(() => _execute(message, mfi, notifier)));
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
      // Signal completion — listeners detect this before _active.remove
      notifier.value = 1.0;
    } catch (_) {
      // Signal failure
      notifier.value = -1.0;
    } finally {
      _active.remove(message.id);
      // Intentionally NOT calling notifier.dispose(): widget lifetimes may
      // outlive the download (e.g. a list rebuild running after the terminal
      // value fires). Disposing here would crash a widget's later
      // removeListener call. The notifier is GC-collected once every listener
      // detaches, so widgets MUST removeListener in their own dispose().
    }
  }
}
