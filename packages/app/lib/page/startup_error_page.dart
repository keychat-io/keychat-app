import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// A standalone error page shown when app startup fails.
///
/// This page intentionally avoids GetX, EasyLoading, and other services
/// that may not be initialized when startup fails.
class StartupErrorPage extends StatelessWidget {
  const StartupErrorPage({
    required this.error,
    required this.stackTrace,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  String get _errorText {
    final buf = StringBuffer()
      ..writeln('Error: $error')
      ..writeln()
      ..writeln('Stack Trace:')
      ..writeln(stackTrace ?? 'N/A');
    return buf.toString();
  }

  Future<String> _buildReportBody() async {
    var appVersion = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}

    final buf = StringBuffer()
      ..writeln('--- Keychat Startup Crash Report ---')
      ..writeln('App Version: $appVersion')
      ..writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
      ..writeln('Dart Version: ${Platform.version}')
      ..writeln('Time: ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln()
      ..writeln(_errorText);
    return buf.toString();
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    final report = await _buildReportBody();
    await Clipboard.setData(ClipboardData(text: report));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error report copied to clipboard')),
      );
    }
  }

  Future<void> _sendEmail() async {
    final report = await _buildReportBody();
    final subject = Uri.encodeComponent('Keychat Startup Crash Report');
    final body = Uri.encodeComponent(report);
    final uri = Uri.parse('mailto:dev@keychat.io?subject=$subject&body=$body');
    try {
      await launchUrl(uri);
    } catch (_) {
      // Email client not available - user can use copy instead
    }
  }

  Future<void> _openGitHubIssue() async {
    final report = await _buildReportBody();
    final title = Uri.encodeComponent('Startup Crash Report');
    final body = Uri.encodeComponent('```\n$report```');
    final uri = Uri.parse(
      'https://github.com/keychat-io/keychat-app/issues/new?title=$title&body=$body',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Startup Failed',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The app encountered an error during initialization. '
                  'Please send the error report to help us fix this issue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _errorText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyToClipboard(context),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sendEmail,
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: const Text('Email'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openGitHubIssue,
                        icon: const Icon(Icons.bug_report_outlined, size: 18),
                        label: const Text('GitHub'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff7748FF),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
