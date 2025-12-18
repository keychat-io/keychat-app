import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/page/setting/UploadedPubkeys.dart';
import 'package:keychat/page/widgets/notice_text_widget.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat/service/unifiedpush.service.dart';
import 'package:keychat/utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:unifiedpush/unifiedpush.dart';

/// Notification settings page with proper state management
class NotificationSettingPage extends StatefulWidget {
  const NotificationSettingPage({super.key});

  @override
  State<NotificationSettingPage> createState() =>
      _NotificationSettingPageState();
}

class _NotificationSettingPageState extends State<NotificationSettingPage> {
  /// Current push type
  PushType _pushType = PushType.fcm;

  /// Current distributor (for UnifiedPush)
  String? _currentDistributor;

  /// Current endpoint (for UnifiedPush)
  PushEndpoint? _currentEndpoint;

  /// FCM token
  String? _fcmToken;

  /// Whether UnifiedPush is registered
  final bool _isUnifiedPushRegistered = false;

  /// Available distributors
  List<String> _availableDistributors = [];

  /// Loading state
  bool _isLoading = true;

  /// Notification enabled status
  bool _isNotificationEnabled = false;

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
      } else {
        _hasPermission = await NotifyService.instance.isNotifyPermissionGrant();
      }
      logger.d(
        '_isNotificationEnabled: $_isNotificationEnabled, _hasPermission: $_hasPermission',
      );
      // Load current push type

      // Load FCM token
      _fcmToken = await NotifyService.instance.deviceId;

      // Load UnifiedPush data
      if (GetPlatform.isAndroid || GetPlatform.isLinux) {
        _currentDistributor = await UnifiedPushService.instance
            .getCurrentDistributor();
        _currentEndpoint = UnifiedPushService.instance.currentEndpoint;
        _availableDistributors = await UnifiedPushService.instance
            .getAvailableDistributors();
      }
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
      appBar: AppBar(title: const Text('Push Notifications')),
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
              description: NoticeTextWidget.warning(
                'When enabled, receiving addresses will be uploaded to the notification server.',
              ),
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
                  final res = await openAppSettings();
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
        if (isAndroidOrLinux && _isNotificationEnabled && _hasPermission)
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
                onPressed: (_) => _showPushTypePicker(),
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
                title: const Text('Registration Status'),
                value: Text(
                  _isUnifiedPushRegistered ? 'Registered' : 'Not Registered',
                  style: TextStyle(
                    color: _isUnifiedPushRegistered
                        ? Colors.green
                        : theme.colorScheme.error,
                  ),
                ),
                trailing: _isUnifiedPushRegistered
                    ? null
                    : TextButton(
                        onPressed: _registerUnifiedPush,
                        child: const Text('Register'),
                      ),
              ),
              if (_currentEndpoint != null)
                SettingsTile(
                  title: const Text('Endpoint'),
                  description: Text(
                    _currentEndpoint!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _currentEndpoint!),
                      );
                      EasyLoading.showSuccess('Copied');
                    },
                  ),
                ),
            ],
          ),

        // FCM Settings
        if (_isNotificationEnabled &&
            _hasPermission &&
            _pushType == PushType.fcm &&
            _fcmToken != null)
          SettingsSection(
            title: const Text('FCM Settings'),
            tiles: [
              SettingsTile(
                title: const Text('Device Token'),
                description: Text(
                  _fcmToken!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _fcmToken!));
                    EasyLoading.showSuccess('Copied');
                  },
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
        return CupertinoActionSheet(
          title: const Text('Select Push Type'),
          message: const Text(
            'FCM uses Google services.\nUnifiedPush is privacy-friendly but requires a distributor app.',
          ),
          actions: [
            CupertinoActionSheetAction(
              isDefaultAction: _pushType == PushType.fcm,
              onPressed: () => Navigator.pop(context, PushType.fcm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud),
                  const SizedBox(width: 8),
                  const Text('FCM (Firebase)'),
                  if (_pushType == PushType.fcm) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, color: Colors.green),
                  ],
                ],
              ),
            ),
            CupertinoActionSheetAction(
              isDefaultAction: _pushType == PushType.unifiedpush,
              onPressed: () => Navigator.pop(context, PushType.unifiedpush),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield),
                  const SizedBox(width: 8),
                  const Text('UnifiedPush'),
                  if (_pushType == PushType.unifiedpush) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, color: Colors.green),
                  ],
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );
      },
    );

    if (result != null && result != _pushType) {
      await _changePushType(result);
    }
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

      // Save new type
      await Storage.setString(
        StorageKeyString.pushNotificationType,
        newType == PushType.fcm ? 'fcm' : 'unifiedpush',
      );

      // Initialize new service
      // set the oldToken for NotifyService to clean up previous registrations
      NotifyService.instance.oldToken = await NotifyService.instance.deviceId;
      if (newType == PushType.fcm) {
        // Initialize FCM
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

  /// Register with UnifiedPush
  Future<void> _registerUnifiedPush() async {
    await EasyLoading.show(status: 'Registering...');

    try {
      if (_currentDistributor == null) {
        // Need to select a distributor first
        await EasyLoading.dismiss();
        await _showDistributorPicker();
        return;
      }

      // Use switchDistributor which handles the timing correctly
      final endpoint = await UnifiedPushService.instance.switchDistributor(
        _currentDistributor!,
      );

      if (endpoint != null) {
        await EasyLoading.showSuccess('Registered');
      } else {
        await EasyLoading.showInfo('Registered, waiting for endpoint...');
      }

      // Reload data
      await _loadData();
    } catch (e) {
      logger.e('Failed to register UnifiedPush', error: e);
      await EasyLoading.showError('Failed to register');
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
        final upService = UnifiedPushService.instance;
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

      // Clear from server and unregister based on push type
      await NotifyService.instance.clearAll();

      if (_pushType == PushType.unifiedpush) {
        // Unregister from UnifiedPush distributor
        await UnifiedPushService.instance.unregister();
      }

      await EasyLoading.showSuccess('Disabled');

      // Reload data
      await _loadData();
    } catch (e, s) {
      logger.e('Disable notification failed', error: e, stackTrace: s);
      await EasyLoading.showError(e.toString());
    }
  }
}
