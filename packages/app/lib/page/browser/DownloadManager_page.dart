import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  List<TaskRecord> _allRecords = [];
  StreamSubscription<TaskUpdate>? _updatesSubscription;
  StreamSubscription<TaskRecord>? _databaseSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDownloadManager();
  }

  Future<void> _initializeDownloadManager() async {
    // Subscribe to task updates
    _updatesSubscription = FileDownloader().updates.listen((update) {
      _loadAllTasks();
    });

    // Subscribe to database updates
    _databaseSubscription = FileDownloader().database.updates.listen((record) {
      _loadAllTasks();
    });

    await _loadAllTasks();
  }

  Future<void> _loadAllTasks() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get all tasks from database
      final records = await FileDownloader().database.allRecords();
      if (!mounted) return;

      setState(() {
        _allRecords = records;
        _isLoading = false;
      });
    } on Exception catch (e) {
      print('Error loading tasks: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _updatesSubscription?.cancel();
    _databaseSubscription?.cancel();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.complete:
        return Colors.green;
      case TaskStatus.failed:
        return Colors.red;
      case TaskStatus.canceled:
        return Colors.orange;
      case TaskStatus.paused:
        return Colors.blue;
      case TaskStatus.running:
        return Colors.blue;
      case TaskStatus.enqueued:
        return Colors.grey;
      case TaskStatus.waitingToRetry:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.complete:
        return Icons.check_circle;
      case TaskStatus.failed:
        return Icons.error;
      case TaskStatus.canceled:
        return Icons.cancel;
      case TaskStatus.paused:
        return Icons.pause_circle;
      case TaskStatus.running:
        return Icons.downloading;
      case TaskStatus.enqueued:
        return Icons.schedule;
      case TaskStatus.waitingToRetry:
        return Icons.refresh;
      default:
        return Icons.help;
    }
  }

  Future<void> _retryTask(Task task) async {
    try {
      await FileDownloader().enqueue(task);
      Get.snackbar(
        'Retry',
        'Download task has been requeued',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _loadAllTasks();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to retry: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _pauseTask(Task task) async {
    if (task is! DownloadTask) return;
    try {
      final result = await FileDownloader().pause(task);
      if (result) {
        Get.snackbar(
          'Paused',
          'Download has been paused',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pause: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _resumeTask(Task task) async {
    if (task is! DownloadTask) return;
    try {
      final result = await FileDownloader().resume(task);
      if (result) {
        Get.snackbar(
          'Resumed',
          'Download has been resumed',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to resume: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _cancelTask(Task task) async {
    final confirmed = await Get.dialog<bool>(
      CupertinoAlertDialog(
        title: const Text('Cancel Download'),
        content: Text(
          'Are you sure you want to cancel downloading "${task.filename}"?',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Get.back(result: false),
            child: const Text('No'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Get.back(result: true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await FileDownloader().cancelTaskWithId(task.taskId);
        Get.snackbar(
          'Canceled',
          'Download has been canceled',
          snackPosition: SnackPosition.BOTTOM,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to cancel: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await Get.dialog<bool>(
      CupertinoAlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.filename}"?'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Get.back(result: false),
            child: const Text('No'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Get.back(result: true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await FileDownloader().database.deleteRecordWithId(task.taskId);
        await _loadAllTasks();
        Get.snackbar(
          'Deleted',
          'Task has been deleted',
          snackPosition: SnackPosition.BOTTOM,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to delete: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _openFile(Task task) async {
    try {
      final filePath = await task.filePath();
      final file = File(filePath);

      if (!file.existsSync()) {
        Get.snackbar(
          'Error',
          'File does not exist',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return;
      }

      final uri = Uri.file(file.parent.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        Get.snackbar(
          'Error',
          'Cannot open file location',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to open: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _clearAllCompleted() async {
    final confirmed = await Get.dialog<bool>(
      CupertinoAlertDialog(
        title: const Text('Clear Completed'),
        content: const Text(
          'Are you sure you want to clear all completed downloads?',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Get.back(result: false),
            child: const Text('No'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Get.back(result: true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        for (final record in _allRecords) {
          if (record.status == TaskStatus.complete) {
            await FileDownloader().database.deleteRecordWithId(record.taskId);
          }
        }
        await _loadAllTasks();
        Get.snackbar(
          'Cleared',
          'All completed downloads have been cleared',
          snackPosition: SnackPosition.BOTTOM,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to clear: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    }
  }

  Widget _buildTaskItem(TaskRecord record) {
    final task = record.task;
    final status = record.status;
    final progress = record.progress;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showTaskDetails(record),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.filename,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.url,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildActionButtons(task, status),
                ],
              ),
              if (status == TaskStatus.running ||
                  status == TaskStatus.paused) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getStatusColor(status),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (record.expectedFileSize > 0)
                      Text(
                        _formatFileSize(record.expectedFileSize),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                status.name.toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Task task, TaskStatus status) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == TaskStatus.running)
          IconButton(
            icon: const Icon(Icons.pause, size: 20),
            onPressed: () => _pauseTask(task),
            tooltip: 'Pause',
          ),
        if (status == TaskStatus.paused)
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 20),
            onPressed: () => _resumeTask(task),
            tooltip: 'Resume',
          ),
        if (status == TaskStatus.failed || status == TaskStatus.canceled)
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _retryTask(task),
            tooltip: 'Retry',
          ),
        if (status == TaskStatus.running ||
            status == TaskStatus.enqueued ||
            status == TaskStatus.paused)
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => _cancelTask(task),
            tooltip: 'Cancel',
          ),
        if (status == TaskStatus.complete)
          IconButton(
            icon: const Icon(Icons.folder_open, size: 20),
            onPressed: () => _openFile(task),
            tooltip: 'Open',
          ),
        IconButton(
          icon: const Icon(Icons.delete, size: 20),
          onPressed: () => _deleteTask(task),
          tooltip: 'Delete',
        ),
      ],
    );
  }

  void _showTaskDetails(TaskRecord record) {
    final task = record.task;
    final status = record.status;
    final progress = record.progress;

    Get.dialog<void>(
      AlertDialog(
        title: const Text('Download Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Filename', task.filename),
              _buildDetailRow('URL', task.url),
              _buildDetailRow('Status', status.name.toUpperCase()),
              if (status == TaskStatus.running || status == TaskStatus.paused)
                _buildDetailRow(
                  'Progress',
                  '${(progress * 100).toStringAsFixed(1)}%',
                ),
              if (record.expectedFileSize > 0)
                _buildDetailRow(
                  'File Size',
                  _formatFileSize(record.expectedFileSize),
                ),
              _buildDetailRow(
                'Directory',
                '${task.baseDirectory}/${task.directory}',
              ),
              _buildDetailRow('Task ID', task.taskId),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
          const Divider(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllTasks,
            tooltip: 'Refresh',
          ),
          if (_allRecords.any((record) => record.status == TaskStatus.complete))
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAllCompleted,
              tooltip: 'Clear Completed',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allRecords.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_done,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No downloads yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAllTasks,
              child: ListView.builder(
                itemCount: _allRecords.length,
                itemBuilder: (context, index) {
                  return _buildTaskItem(_allRecords[index]);
                },
              ),
            ),
    );
  }
}
