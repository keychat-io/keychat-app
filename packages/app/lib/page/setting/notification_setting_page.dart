import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/page/setting/UploadedPubkeys.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat/service/unifiedpush.service.dart';
import 'package:keychat/utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:unifiedpush/unifiedpush.dart';
import 'package:url_launcher/url_launcher.dart';

/// Notification settings page with proper state management
class NotificationSettingPage extends StatefulWidget {
  const NotificationSettingPage({super.key});

  @override
  State<NotificationSettingPage> createState() =>
      _NotificationSettingPageState();
}

class _NotificationSettingPageState extends State<NotificationSettingPage> {
  /// Current push type
  PushType _pushType = GetPlatform.isLinux
      ? PushType.unifiedpush
      : PushType.fcm;

  /// Current distributor (for UnifiedPush)
  String? _currentDistributor;

  /// Current endpoint (for UnifiedPush)
  PushEndpoint? _currentEndpoint;

  /// FCM token
  String? _fcm;

  /// Available distributors
  List<String> _availableDistributors = [];

  /// Loading state
  bool _isLoading = true;

  /// Notification enabled status
  bool _isNotificationEnabled = true;

  /// Whether app has notification permission
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load notification status
      final homeController = Get.find<HomeController>();
      _isNotificationEnabled = homeController.isNotificationEnabled;

      _pushType = NotifyService.instance.currentPushType;
      if (_pushType == PushType.unifiedpush) {
        _hasPermission = true;
        if (_isNotificationEnabled) {
          if (GetPlatform.isAndroid || GetPlatform.isLinux) {
            await UnifiedPushService.instance.init(
              autoPromptDistributor: false,
            );
            _currentDistributor = await UnifiedPushService.instance
                .getCurrentDistributor();
            _currentEndpoint = UnifiedPushService.instance.currentEndpoint;
            _availableDistributors = await UnifiedPushService.instance
                .getAvailableDistributors();
            _currentEndpoint = await UnifiedPushService.instance
                .getCurrentEndpointWithRetry();
          }
        }
      } else {
        _hasPermission = await NotifyService.instance.isNotifyPermissionGrant();
      }
      if (_isNotificationEnabled) {
        _fcm = await NotifyService.instance.deviceId;
      }
      logger.d(
        '_isNotificationEnabled: $_isNotificationEnabled, _hasPermission: $_hasPermission',
      );
    } catch (e) {
      logger.e('Failed to load notification settings', error: e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final isAndroidOrLinux = GetPlatform.isAndroid || GetPlatform.isLinux;

    return SettingsList(
      platform: DevicePlatform.iOS,
      sections: [
        // Notification Master Switch
        SettingsSection(
          title: const Text('Notification Status'),
          tiles: [
            SettingsTile.switchTile(
              initialValue: _isNotificationEnabled && _hasPermission,
              title: const Text('Enable Notifications'),
              onToggle: (value) async {
                if (value) {
                  await _enableNotification();
                } else {
                  await _disableNotification();
                }
              },
            ),
            if (_pushType != PushType.unifiedpush)
              SettingsTile(
                title: const Text('App Permission'),
                value: Text(
                  _hasPermission ? 'Granted' : 'Not Granted',
                  style: TextStyle(
                    color: _hasPermission ? Colors.green : Colors.red,
                  ),
                ),
                onPressed: (_) async {
                  await openAppSettings();
                  await _loadData();
                },
              ),
            SettingsTile.navigation(
              title: const Text('Listening Pubkey Stats'),
              onPressed: (context) async {
                Get.to<void>(() => const UploadedPubkeys());
              },
            ),
          ],
        ),

        // Push Type Selection (Android/Linux only)
        if (isAndroidOrLinux)
          SettingsSection(
            title: const Text('Push Service'),
            tiles: [
              SettingsTile(
                title: const Text('Push Type'),
                description: Text(_getPushTypeDescription()),
                value: Text(
                  _pushType == PushType.fcm ? 'FCM' : 'UnifiedPush',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
                trailing: const Icon(Icons.chevron_right),
                onPressed: (_) async {
                  if (_pushType == PushType.fcm && GetPlatform.isLinux) {
                    EasyLoading.showInfo(
                      'On Linux, only UnifiedPush is supported.',
                    );
                    return;
                  }
                  await _showPushTypePicker();
                },
              ),
            ],
          ),

        // UnifiedPush Settings
        if (isAndroidOrLinux &&
            _isNotificationEnabled &&
            _hasPermission &&
            _pushType == PushType.unifiedpush)
          SettingsSection(
            title: const Text('UnifiedPush Settings'),
            tiles: [
              SettingsTile(
                title: const Text('Distributor'),
                value: Text(
                  _currentDistributor != null
                      ? _formatDistributorName(_currentDistributor!)
                      : 'Not Selected',
                  style: TextStyle(
                    color: _currentDistributor != null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onPressed: (_) => _showDistributorPicker(),
              ),
              SettingsTile(
                title: const Text('Endpoint Info'),
                onPressed: (context) async {
                  if (_currentEndpoint?.url == null) return;
                  await Clipboard.setData(
                    ClipboardData(text: _currentEndpoint!.url),
                  );
                  await EasyLoading.showSuccess('Copied to clipboard');
                },
                description: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text(
                      'Server: ${_currentEndpoint?.url}',
                    ),
                    if (_currentEndpoint?.pubKeySet?.auth != null) ...[
                      Text(
                        'auth: ${_currentEndpoint!.pubKeySet!.auth}',
                      ),
                      Text(
                        'pubKey: ${_currentEndpoint!.pubKeySet!.pubKey}',
                      ),

                      const Text(
                        'Web Push: https://www.rfc-editor.org/rfc/rfc8291',
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          if (_currentEndpoint == null) return;
                          final endpointInfo = StringBuffer()
                            ..writeln(
                              'Server: ${_currentEndpoint!.url}',
                            );
                          if (_currentEndpoint!.pubKeySet?.auth != null) {
                            endpointInfo
                              ..writeln(
                                'auth: ${_currentEndpoint!.pubKeySet!.auth}',
                              )
                              ..writeln(
                                'pubKey: ${_currentEndpoint!.pubKeySet!.pubKey}',
                              );
                          }
                          await Clipboard.setData(
                            ClipboardData(text: endpointInfo.toString()),
                          );
                          await EasyLoading.showSuccess('Copied to clipboard');
                        },
                        child: const Text('Copy Endpoint Info'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

        // FCM Settings
        if (_pushType == PushType.fcm && _isNotificationEnabled)
          SettingsSection(
            title: const Text('FCM Settings'),
            tiles: [
              SettingsTile(
                title: const Text('FCM Token'),
                value: Text(
                  ((_fcm ?? '--').length) > 8
                      ? '${_fcm?.substring(0, 8)}...'
                      : '--',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _getPushTypeDescription() {
    if (_pushType == PushType.fcm) {
      return 'Using Firebase Cloud Messaging (Google)';
    } else {
      return 'Using UnifiedPush (Privacy-friendly)';
    }
  }

  /// Show push type picker dialog
  Future<void> _showPushTypePicker() async {
    final result = await showCupertinoModalPopup<PushType>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Select Push Service',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // FCM Option
                  _buildPushTypeCard(
                    context: context,
                    icon: Icons.cloud,
                    iconColor: Colors.orange,
                    title: 'FCM (Firebase)',
                    description:
                        'Fast and reliable push notifications using Google Firebase Cloud Messaging',
                    pros: [
                      'Easy setup, works out of the box',
                    ],
                    cons: [
                      'Requires Google Play Services',
                    ],
                    isSelected: _pushType == PushType.fcm,
                    onTap: () => Navigator.pop(context, PushType.fcm),
                  ),
                  const SizedBox(height: 16),

                  // UnifiedPush Option
                  _buildPushTypeCard(
                    context: context,
                    icon: Icons.shield_outlined,
                    iconColor: Colors.green,
                    title: 'UnifiedPush',
                    description:
                        'Privacy-friendly, open-source push notification system',
                    pros: [
                      'Privacy-focused & decentralized',
                      'No Google services needed',
                      'Open source',
                    ],
                    cons: [
                      'Requires distributor app',
                    ],
                    isSelected: _pushType == PushType.unifiedpush,
                    isRecommended: true,
                    onTap: () => Navigator.pop(context, PushType.unifiedpush),
                    footer: _buildUnifiedPushFooter(context),
                  ),
                  const SizedBox(height: 16),

                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != null && result != _pushType) {
      await _changePushType(result);
    }
  }

  Widget _buildPushTypeCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required List<String> pros,
    required List<String> cons,
    required bool isSelected,
    required VoidCallback onTap,
    bool isRecommended = false,
    Widget? footer,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
              ],
            ),
            const SizedBox(height: 12),

            // Pros
            ...pros.map(
              (pro) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pro,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Cons
            ...cons.map(
              (con) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        con,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (footer != null) ...[
              const SizedBox(height: 8),
              footer,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedPushFooter(BuildContext context) {
    final isLinux = GetPlatform.isLinux;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              Text(
                'Distributor App Required',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLinux)
            Text(
              'For Linux, install: KUnifiedPush',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Text(
              'Install one of: Ntfy, Sunup, or other UnifiedPush distributors',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              await launchUrl(Uri.parse('https://unifiedpush.org/'));
            },
            child: Row(
              children: [
                Icon(Icons.open_in_new, size: 14, color: Colors.blue[700]),
                const SizedBox(width: 4),
                Text(
                  'Learn more at unifiedpush.org',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Change push type
  Future<void> _changePushType(PushType newType) async {
    try {
      if (newType == PushType.unifiedpush) {
        // Check if any distributors available BEFORE switching
        final distributors = await UnifiedPushService.instance
            .getAvailableDistributors();
        if (distributors.isEmpty) {
          await EasyLoading.showError(
            'No UnifiedPush distributors found.\nPlease install a distributor app like ntfy or NextPush.',
          );
          return;
        }
      }

      await EasyLoading.show(status: 'Switching...');

      // set the oldToken for NotifyService to clean up previous registrations
      NotifyService.instance.oldToken = await NotifyService.instance.deviceId;

      // Save new type
      await Storage.setString(
        StorageKeyString.pushNotificationType,
        newType == PushType.fcm ? 'fcm' : 'unifiedpush',
      );

      // Initialize new service
      if (newType == PushType.fcm) {
        await NotifyService.instance.init(
          requestPermission: true,
        );
        await UnifiedPushService.instance.unregister();
      } else {
        // Initialize UnifiedPush
        final upService = UnifiedPushService.instance;

        // Initialize UnifiedPush service - don't auto prompt, we handle it here
        await upService.init(autoPromptDistributor: false);
        final currentEndpoint = await upService.getCurrentEndpointWithRetry();
        // Check if we have an endpoint after init
        if (currentEndpoint == null) {
          // If no endpoint yet, might need user to select distributor
          await EasyLoading.dismiss();

          // Check if we need to show distributor picker
          final currentDistributor = await upService.getCurrentDistributor();
          if (currentDistributor == null) {
            await _showDistributorPicker();
          }
          // Reload data
          await _loadData();
          return;
        }
      }

      await EasyLoading.showSuccess('Switched successfully');

      // Reload data
      await _loadData();
    } catch (e) {
      logger.e('Failed to switch push type', error: e);
      await EasyLoading.showError('Failed to switch: $e');
    }
  }

  /// Show distributor picker dialog
  Future<void> _showDistributorPicker() async {
    // Refresh available distributors
    _availableDistributors = await UnifiedPushService.instance
        .getAvailableDistributors();

    if (_availableDistributors.isEmpty) {
      await EasyLoading.showError(
        'No UnifiedPush distributors found.\nPlease install a distributor app like ntfy or NextPush.',
      );
      return;
    }

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select Distributor'),
          children: _availableDistributors.map((distributor) {
            final isSelected = distributor == _currentDistributor;
            final displayName = _formatDistributorName(distributor);
            return SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(distributor),
              child: ListTile(
                leading: Icon(
                  Icons.notifications_active,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(displayName),
                subtitle: Text(
                  distributor,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );

    if (result != null && result != _currentDistributor) {
      await _switchDistributor(result);
    }
  }

  /// Switch to a new distributor
  Future<void> _switchDistributor(String distributor) async {
    await EasyLoading.show(status: 'Switching distributor...');

    try {
      // Use the service's switchDistributor which handles the timing correctly
      final endpoint = await UnifiedPushService.instance.switchDistributor(
        distributor,
      );

      if (endpoint != null) {
        await EasyLoading.showSuccess('Distributor changed');
      } else {
        await EasyLoading.showInfo(
          'Distributor saved, waiting for endpoint...',
        );
      }

      // Reload data
      await _loadData();
    } catch (e) {
      logger.e('Failed to switch distributor', error: e);
      await EasyLoading.showError('Failed to switch distributor');
    }
  }

  /// Format distributor package name to a more readable display name
  String _formatDistributorName(String packageName) {
    final knownDistributors = {
      'org.unifiedpush.distributor.fcm': 'FCM Distributor',
      'org.unifiedpush.distributor.nextpush': 'NextPush',
      'io.heckel.ntfy': 'ntfy',
      'org.unifiedpush.distributor.noprovider2push': 'NoProvider2Push',
      'im.vector.app': 'Element',
      'de.pixart.messenger': 'Pix-Art Messenger',
      'eu.siacs.conversations': 'Conversations',
    };

    if (knownDistributors.containsKey(packageName)) {
      return knownDistributors[packageName]!;
    }

    // Extract last part of package name and capitalize
    final parts = packageName.split('.');
    if (parts.isNotEmpty) {
      final name = parts.last;
      return name[0].toUpperCase() + name.substring(1);
    }
    return packageName;
  }

  /// Enable notifications
  Future<void> _enableNotification() async {
    final confirmed = await Get.dialog<bool>(
      CupertinoAlertDialog(
        title: const Text('Alert'),
        content: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 15),
          child: const Text(
            'Once activated, your receiving addresses will be automatically uploaded to the notification server.',
          ),
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Get.back(result: false),
          ),
          CupertinoDialogAction(
            child: const Text('Confirm'),
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await EasyLoading.show(status: 'Initializing...');
      await Get.find<HomeController>().enableNotification();

      // Initialize notification service based on push type
      if (_pushType == PushType.fcm) {
        // Initialize FCM
        await NotifyService.instance.init(requestPermission: true);

        // Check permission
        final hasPermission = await NotifyService.instance
            .isNotifyPermissionGrant();
        if (!hasPermission) {
          await EasyLoading.showError(
            'Please enable notification permission in system settings',
          );
          await openAppSettings();
          return;
        }

        // Sync to server
        await NotifyService.instance.syncPubkeysToServer();
      } else {
        // Initialize UnifiedPush
        //
        final upService = UnifiedPushService.instance;
        await upService.unregister();
        await upService.init(autoPromptDistributor: false);

        // Try to get endpoint with retry
        final endpoint = await upService.getCurrentEndpointWithRetry();

        if (endpoint == null) {
          // Need to select distributor
          await EasyLoading.dismiss();

          final currentDistributor = await upService.getCurrentDistributor();
          if (currentDistributor == null) {
            await _showDistributorPicker();
          } else {
            // Re-register with current distributor
            await upService.switchDistributor(currentDistributor);
          }

          await _loadData();
          return;
        }

        // Sync to server
        await NotifyService.instance.syncPubkeysToServer();
      }

      await EasyLoading.showSuccess('Enabled');

      // Reload data
      await _loadData();
    } catch (e, s) {
      logger.e('Enable notification failed', error: e, stackTrace: s);
      await EasyLoading.showError(e.toString());
    } finally {
      await Future<void>.delayed(const Duration(seconds: 1));
      await EasyLoading.dismiss();
    }
  }

  /// Disable notifications
  Future<void> _disableNotification() async {
    final confirmed = await Get.dialog<bool>(
      CupertinoAlertDialog(
        title: const Text('Alert'),
        content: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 15),
          child: const Text(
            'Once deactivated, your receiving addresses will be automatically deleted from the notification server.',
          ),
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Get.back(result: false),
          ),
          CupertinoDialogAction(
            child: const Text('Confirm'),
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await EasyLoading.show(status: 'Processing');

      await Get.find<HomeController>().disableNotification();
      _isNotificationEnabled = false;
      // Clear from server and unregister based on push type
      await NotifyService.instance.clearAll();
      await EasyLoading.showSuccess('Disabled');

      // Reload data
      await _loadData();
    } catch (e, s) {
      logger.e('Disable notification failed', error: e, stackTrace: s);
      await EasyLoading.showError(e.toString());
    }
  }
}
