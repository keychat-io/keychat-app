import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/page/browser/MultiWebviewController.dart';

/// Example widget showing how to add AdBlock management to browser settings
///
/// This can be integrated into BrowserSetting.dart or shown as a dialog
class AdBlockSettingsWidget extends StatefulWidget {
  const AdBlockSettingsWidget({super.key});

  @override
  State<AdBlockSettingsWidget> createState() => _AdBlockSettingsWidgetState();
}

class _AdBlockSettingsWidgetState extends State<AdBlockSettingsWidget> {
  final MultiWebviewController controller = Get.find<MultiWebviewController>();
  Map<String, dynamic>? cacheInfo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    setState(() => isLoading = true);
    try {
      final info = await controller.getAdBlockCacheInfo();
      setState(() {
        cacheInfo = info;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      EasyLoading.showError('Failed to load: $e');
    }
  }

  Future<void> _refreshRules() async {
    EasyLoading.show(status: 'Updating AdBlock rules...');
    try {
      await controller.refreshAdBlockRules();
      await _loadCacheInfo();
      EasyLoading.showSuccess('AdBlock rules updated');
    } catch (e) {
      EasyLoading.showError('Update failed: $e');
    }
  }

  String _formatAge(int? hours) {
    if (hours == null) return 'Unknown';
    if (hours < 24) return '$hours hours';
    final days = (hours / 24).floor();
    return '$days days';
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.block, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'AdBlock',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (!isLoading)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadCacheInfo,
                    tooltip: 'Refresh status',
                  ),
              ],
            ),
            const Divider(height: 24),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (cacheInfo != null) ...[
              _buildInfoRow(
                'Rules count',
                '${cacheInfo!['blockerCount']} rules',
                Icons.rule,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                'Cache status',
                cacheInfo!['exists'] == true ? 'Cached' : 'Not cached',
                Icons.cached,
                color: cacheInfo!['exists'] == true
                    ? Colors.green
                    : Colors.orange,
              ),
              if (cacheInfo!['exists'] == true) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  'Cache age',
                  _formatAge(cacheInfo!['age'] as int?),
                  Icons.schedule,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  'Cache size',
                  _formatSize(cacheInfo!['size'] as int?),
                  Icons.storage,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _refreshRules,
                  icon: const Icon(Icons.update),
                  label: const Text('Update AdBlock Rules'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: Rules auto-update every 7 days',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Example: Show AdBlock settings as a dialog
void showAdBlockSettingsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'AdBlock Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const AdBlockSettingsWidget(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

/// Example: Add to BrowserSetting.dart as a settings tile
Widget buildAdBlockSettingsTile(BuildContext context) {
  return ListTile(
    leading: const Icon(Icons.block),
    title: const Text('AdBlock'),
    subtitle: const Text('Manage AdBlock rules'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => showAdBlockSettingsDialog(context),
  );
}
