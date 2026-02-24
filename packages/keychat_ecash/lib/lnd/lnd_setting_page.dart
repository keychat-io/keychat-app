import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/utils.dart' show DesktopContainer;
import 'package:keychat_ecash/lnd/active_lnd_connection.dart';
import 'package:keychat_ecash/lnd/lnd_controller.dart';
import 'package:keychat_ecash/lnd/lnd_rest_client.dart';

/// Settings page for LND wallet connection details.
class LndSettingPage extends GetView<LndController> {
  const LndSettingPage({required this.connection, super.key});

  final ActiveLndConnection connection;

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController(text: connection.info.name);
    final infoFuture = controller.getInfo(connection.info.uri);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LND Connection Details'),
        actions: [
          MenuAnchor(
            builder: (
              BuildContext context,
              MenuController menuController,
              Widget? child,
            ) {
              return IconButton(
                onPressed: () {
                  if (menuController.isOpen) {
                    menuController.close();
                  } else {
                    menuController.open();
                  }
                },
                icon: const Icon(Icons.more_vert),
              );
            },
            menuChildren: <Widget>[
              MenuItemButton(
                onPressed: _showDeleteDialog,
                child: const Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Delete Connection',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: DesktopContainer(
        child: FutureBuilder<LndGetInfoResponse?>(
          future: infoFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final info = snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Primary Info Card - Name and Host
                _buildPrimaryInfoCard(context, nameController),
                const SizedBox(height: 20),

                // Node Details
                if (info != null) ..._buildInfoSection(context, info),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPrimaryInfoCard(
    BuildContext context,
    TextEditingController nameController,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name Field
            Text(
              'Wallet Name',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Enter wallet name (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    await controller.updateConnectionName(
                      connection.info.uri,
                      newName,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Host Field
            Text(
              'Host',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${connection.info.host}:${connection.info.port}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                              '${connection.info.host}:${connection.info.port}',
                        ),
                      );
                      await EasyLoading.showSuccess('Copied');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog() async {
    final confirmed = await Get.dialog<bool>(
      CupertinoAlertDialog(
        title: const Text('Delete Connection?'),
        content: const Text(
          'Are you sure you want to remove this LND connection? '
          'This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Get.back<bool>(result: false);
            },
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Get.back<bool>(result: true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) return;

    try {
      final deleted = await controller.deleteConnection(connection.info.uri);
      await EasyLoading.showToast('Wallet deleted');
      Get.back(
        result: deleted,
        id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
      );
    } catch (e) {
      await EasyLoading.showError(e.toString());
    }
  }

  List<Widget> _buildInfoSection(
    BuildContext context,
    LndGetInfoResponse info,
  ) {
    return [
      // Node Information Card
      Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.bolt,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Node Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (info.alias.isNotEmpty) ...[
                _buildInfoRow(
                  context,
                  icon: Icons.label,
                  label: 'Alias',
                  value: info.alias,
                ),
                const SizedBox(height: 12),
              ],
              _buildInfoRow(
                context,
                icon: Icons.cloud,
                label: 'Network',
                value: info.network,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                icon: Icons.layers,
                label: 'Block Height',
                value: info.blockHeight.toString(),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                icon: CupertinoIcons.arrow_right_arrow_left,
                label: 'Active Channels',
                value: info.numActiveChannels.toString(),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                icon: Icons.people,
                label: 'Peers',
                value: info.numPeers.toString(),
              ),
              if (info.version != null && info.version!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  icon: Icons.info_outline,
                  label: 'Version',
                  value: info.version!,
                ),
              ],
              if (info.identityPubkey.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  icon: Icons.key,
                  label: 'Public Key',
                  value: _truncatePubkey(info.identityPubkey),
                  onCopy: () async {
                    await Clipboard.setData(
                      ClipboardData(text: info.identityPubkey),
                    );
                    await EasyLoading.showSuccess('Copied');
                  },
                ),
              ],
            ],
          ),
        ),
      ),

      // Sync Status Card
      const SizedBox(height: 16),
      Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sync,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sync Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildSyncChip(
                    context,
                    label: 'Chain',
                    isSynced: info.syncedToChain,
                  ),
                  const SizedBox(width: 8),
                  _buildSyncChip(
                    context,
                    label: 'Graph',
                    isSynced: info.syncedToGraph,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: onCopy,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Widget _buildSyncChip(
    BuildContext context, {
    required String label,
    required bool isSynced,
  }) {
    return Chip(
      label: Text(
        '$label: ${isSynced ? 'Synced' : 'Syncing'}',
        style: TextStyle(
          color: isSynced
              ? Theme.of(context).colorScheme.onSecondaryContainer
              : Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      avatar: Icon(
        isSynced ? Icons.check_circle : Icons.sync,
        size: 16,
        color: isSynced
            ? Theme.of(context).colorScheme.onSecondaryContainer
            : Theme.of(context).colorScheme.onErrorContainer,
      ),
      backgroundColor: isSynced
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.errorContainer,
      side: BorderSide.none,
    );
  }

  String _truncatePubkey(String pubkey) {
    if (pubkey.length <= 20) return pubkey;
    return '${pubkey.substring(0, 10)}...${pubkey.substring(pubkey.length - 10)}';
  }
}
