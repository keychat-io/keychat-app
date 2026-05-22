import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/page/routes.dart';
import 'package:keychat/service/report.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/utils.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({
    required this.room,
    required this.reportType,
    super.key,
    this.message,
    this.canBlockUser = false,
  });

  final Room room;
  final Message? message;
  final ReportType reportType;
  final bool canBlockUser;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TextEditingController _contextController = TextEditingController();
  late Future<List<ReportReason>> _reasonsFuture;
  String? _selectedReasonValue;
  bool _includeSelectedMessage = true;
  bool _submitting = false;

  bool get _isMessageReport => widget.reportType == ReportType.message;

  @override
  void initState() {
    super.initState();
    _reasonsFuture = ReportService.instance.getReasons();
  }

  @override
  void dispose() {
    _contextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMessageReport ? 'Report Message' : 'Report User'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<ReportReason>>(
          future: _reasonsFuture,
          builder: (context, snapshot) {
            final reasons = snapshot.data ?? ReportService.fallbackReasons;
            final reasonValues = reasons.map((reason) => reason.value).toSet();
            if (_selectedReasonValue == null ||
                !reasonValues.contains(_selectedReasonValue)) {
              _selectedReasonValue = reasons.first.value;
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _isMessageReport
                      ? 'Selected messages will be decrypted on your device and sent to Keychat for review.'
                      : 'This report will be sent to Keychat for review.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _selectedReasonValue,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: reasons
                      .map(
                        (reason) => DropdownMenuItem(
                          value: reason.value,
                          child: Text(reason.label),
                        ),
                      )
                      .toList(),
                  onChanged: (reasonValue) {
                    setState(() {
                      _selectedReasonValue = reasonValue;
                    });
                  },
                ),
                if (_isMessageReport) ...[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _includeSelectedMessage,
                    title: const Text('Include selected message'),
                    subtitle: Text(
                      _messagePreview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _includeSelectedMessage = value ?? true;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _contextController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Additional context',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submitReport,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.report_gmailerrorred),
                  label: const Text('Submit Report'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String get _messagePreview {
    final message = widget.message;
    if (message == null) return '';
    return message.realMessage ?? message.content;
  }

  Future<void> _submitReport() async {
    final reasonValue = _selectedReasonValue;
    if (reasonValue == null) {
      await EasyLoading.showError('Please select a reason');
      return;
    }
    if (_isMessageReport &&
        !_includeSelectedMessage &&
        _contextController.text.trim().isEmpty) {
      await EasyLoading.showError('Please include evidence or context');
      return;
    }

    setState(() {
      _submitting = true;
    });
    try {
      final request = await _buildRequest(reasonValue);
      await ReportService.instance.submitReport(request);
      if (!mounted) return;
      await _showSubmittedDialog();
    } catch (e, s) {
      logger.e('submit report error', error: e, stackTrace: s);
      await EasyLoading.showError(Utils.getErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<ReportRequest> _buildRequest(String reason) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final message = widget.message;
    final reportedPubkey = message?.idPubkey.isNotEmpty == true
        ? message!.idPubkey
        : widget.room.toMainPubkey;
    final messageText = message == null
        ? null
        : message.realMessage ?? message.content;
    final selectedMessages = <Map<String, dynamic>>[];
    if (_isMessageReport &&
        _includeSelectedMessage &&
        message != null &&
        messageText != null) {
      selectedMessages.add({
        'messageId': message.id > 0 ? message.id.toString() : message.msgid,
        'senderPubkey': reportedPubkey,
        'sentAt': message.createdAt.toUtc().toIso8601String(),
        'plaintext': messageText,
      });
    }

    return ReportRequest(
      reportType: widget.reportType,
      reason: reason,
      reporterPubkey: widget.room.myIdPubkey,
      reportedPubkey: reportedPubkey,
      roomId: widget.room.id.toString(),
      messageId: message == null
          ? null
          : (message.id > 0 ? message.id.toString() : message.msgid),
      eventId: message?.msgid,
      relayUrls: {
        ...widget.room.sendingRelays,
        ...widget.room.receivingRelays,
      }.toList(),
      evidence: selectedMessages.isEmpty
          ? null
          : {'selectedMessages': selectedMessages},
      additionalContext: _contextController.text,
      clientMeta: {
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'platform': _platformName,
        'locale': Get.locale?.toLanguageTag(),
      },
    );
  }

  String get _platformName {
    if (GetPlatform.isIOS) return 'ios';
    if (GetPlatform.isAndroid) return 'android';
    if (GetPlatform.isMacOS) return 'macos';
    if (GetPlatform.isWindows) return 'windows';
    if (GetPlatform.isLinux) return 'linux';
    return 'unknown';
  }

  Future<void> _showSubmittedDialog() async {
    await Get.dialog<void>(
      CupertinoAlertDialog(
        title: const Text('Report submitted'),
        content: Text(
          widget.canBlockUser
              ? 'Thanks. We will review this report. You can block this user to stop seeing their messages.'
              : 'Thanks. We will review this report.',
        ),
        actions: [
          if (widget.canBlockUser)
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Get.back<void>();
                await _blockUser();
              },
              child: const Text('Block User'),
            ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Get
                ..back<void>()
                ..back<void>(
                  id: GetPlatform.isDesktop ? GetXNestKey.room : null,
                );
            },
            child: const Text('Done'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _blockUser() async {
    try {
      await RoomService.instance.deleteRoom(widget.room);
      await EasyLoading.showSuccess('User blocked');
      await Utils.offAllNamedRoom(Routes.root);
    } catch (e, s) {
      logger.e('block reported user error', error: e, stackTrace: s);
      await EasyLoading.showError(Utils.getErrorMessage(e));
    }
  }
}
