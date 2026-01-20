import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:keychat/utils.dart' show DesktopContainer;
import 'package:keychat_nwc/active_nwc_connection.dart';
import 'package:keychat_nwc/nwc/nwc_controller.dart';
import 'package:ndk/ndk.dart';

class NwcSettingPage extends GetView<NwcController> {
  const NwcSettingPage({required this.connection, super.key});
  final ActiveNwcConnection connection;

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController(text: connection.info.name);
    final infoFuture = controller.getInfo(connection.info.uri);
    return Scaffold(
      appBar: AppBar(
        title: const Text('NWC Connection Details'),
        actions: [
          MenuAnchor(
            builder: (
              BuildContext context,
              MenuController controller,
              Widget? child,
            ) {
              return IconButton(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
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
        child: FutureBuilder<GetInfoResponse?>(
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
                // Primary Info Card - Name and URI
                _buildPrimaryInfoCard(context, nameController),
                const SizedBox(height: 20),

                // Connection Details
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

            // URI Field
            Text(
              'Connection URI',
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
                      connection.info.uri,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: connection.info.uri),
                      );
                      Get.snackbar(
                        'Copied',
                        'Connection URI copied to clipboard',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 2),
                      );
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
          'Are you sure you want to remove this NWC connection? This action cannot be undone.',
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
            onPressed: () async {
              Get.back<bool>(result: true); // Close settings page
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await controller.deleteConnection(connection.info.uri);
    Get.back<bool>(result: true);
  }

  List<Widget> _buildInfoSection(BuildContext context, GetInfoResponse info) {
    return [
      // Server Information Card
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
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Server Information',
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
                value: info.network.plaintext,
              ),
              if (info.blockHeight != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  icon: Icons.layers,
                  label: 'Block Height',
                  value: info.blockHeight.toString(),
                ),
              ],
              if (info.pubkey != null && info.pubkey!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  icon: Icons.key,
                  label: 'Public Key',
                  value:
                      '${info.pubkey!.substring(0, 16)}...${info.pubkey!.substring(info.pubkey!.length - 16)}',
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: info.pubkey!));
                    Get.snackbar(
                      'Copied',
                      'Public key copied to clipboard',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 2),
                    );
                  },
                ),
              ],
              if (info.blockHash != null && info.blockHash!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  icon: Icons.tag,
                  label: 'Block Hash',
                  value:
                      '${info.blockHash!.substring(0, 16)}...${info.blockHash!.substring(info.blockHash!.length - 16)}',
                ),
              ],
            ],
          ),
        ),
      ),

      // Notifications Card (if available)
      if (info.notifications.isNotEmpty) ...[
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
                      Icons.notifications_active,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: info.notifications
                      .map(
                        (notification) => Chip(
                          label: Text(
                            notification,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                          avatar: Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.secondaryContainer,
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ],

      // Supported Methods Card
      if (info.methods.isNotEmpty) ...[
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
                      Icons.api,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Supported Methods',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: info.methods
                      .map(
                        (method) => Chip(
                          label: Text(
                            method,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onTertiaryContainer,
                            ),
                          ),
                          avatar: Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer,
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.tertiaryContainer,
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ],
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
}
