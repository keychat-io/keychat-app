import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/utils.dart';
import 'package:unifiedpush/unifiedpush.dart';
import 'package:unifiedpush_platform_interface/unifiedpush_platform_interface.dart'
    show LinuxOptions;
import 'package:unifiedpush_storage_shared_preferences/storage.dart';

/// UnifiedPush Service for handling push notifications without Google Services
///
/// Flow:
/// 1. Call `init()` during app startup (after user login)
/// 2. `init()` calls `UnifiedPush.initialize()` to setup callbacks
/// 3. If no distributor is registered, try to use default or show picker dialog
/// 4. After registration, `onNewEndpoint` is called with the push endpoint
/// 5. Send the endpoint to your application server
/// 6. When a push message arrives, `onMessage` is called
class UnifiedPushService {
  // Singleton pattern
  UnifiedPushService._();
  static UnifiedPushService? _instance;
  static UnifiedPushService get instance =>
      _instance ??= UnifiedPushService._();

  static const pushInstance = 'default';

  /// DBus name for Linux (should match your application ID)

  /// Current push endpoint URL (received from distributor)
  String? _currentEndpoint;
  String? get currentEndpoint => _currentEndpoint;

  /// Whether the service has been initialized
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Whether we are registered with a distributor
  bool _isRegistered = false;
  bool get isRegistered => _isRegistered;

  /// Get the currently saved distributor
  Future<String?> getCurrentDistributor() async {
    return UnifiedPush.getDistributor();
  }

  /// Get list of available distributors
  Future<List<String>> getAvailableDistributors() async {
    return UnifiedPush.getDistributors();
  }

  /// Initialize UnifiedPush service
  ///
  /// Call this during app startup after user has logged in.
  /// [args] - Command line arguments (for Linux background support)
  Future<void> init([List<String> args = const []]) async {
    // UnifiedPush only supports Android and Linux
    if (!GetPlatform.isAndroid && !GetPlatform.isLinux) {
      logger.i(
        '[UnifiedPush] Only supported on Android/Linux platforms, skipping',
      );
      return;
    }

    logger.i('[UnifiedPush] Starting initialization...');

    if (_isInitialized) {
      logger.i('[UnifiedPush] Already initialized, skipping');
      return;
    }

    // Configure Linux options if on Linux platform
    LinuxOptions? linuxOptions;
    if (GetPlatform.isLinux) {
      final isBackground = args.contains('--unifiedpush-bg');
      logger.i(
        '[UnifiedPush] Linux platform detected, background: $isBackground',
      );
      linuxOptions = LinuxOptions(
        dbusName: KeychatGlobal.appPackageName,
        storage: UnifiedPushStorageSharedPreferences(),
        background: isBackground,
      );
    }

    // Initialize UnifiedPush with callbacks
    // Returns true if already registered with a distributor
    final alreadyRegistered = await UnifiedPush.initialize(
      onNewEndpoint: _onNewEndpoint,
      onRegistrationFailed: _onRegistrationFailed,
      onUnregistered: _onUnregistered,
      onMessage: _onMessage,
      onTempUnavailable: _onTempUnavailable,
      linuxOptions: linuxOptions,
    );

    _isInitialized = true;
    logger.i(
      '[UnifiedPush] Initialized. Already registered: $alreadyRegistered',
    );

    if (alreadyRegistered) {
      // Already registered, just refresh the registration
      _isRegistered = true;
      logger.i('[UnifiedPush] Refreshing existing registration...');
      await UnifiedPush.register();
      return;
    }

    // Not registered yet, try to find a distributor
    logger.i('[UnifiedPush] Not registered, looking for distributors...');

    // First try to use the saved or default distributor
    final success = await UnifiedPush.tryUseCurrentOrDefaultDistributor();
    logger.i('[UnifiedPush] tryUseCurrentOrDefaultDistributor: $success');

    if (success) {
      // Found a distributor, register with it
      logger.i('[UnifiedPush] Using default/saved distributor, registering...');
      await UnifiedPush.register();
    } else {
      // No default distributor, need user to choose
      logger.i('[UnifiedPush] No default distributor, prompting user...');
      await _promptUserForDistributor();
    }
  }

  /// Let user choose a distributor from available ones
  Future<void> _promptUserForDistributor() async {
    final distributors = await UnifiedPush.getDistributors();
    logger.i('[UnifiedPush] Available distributors: $distributors');

    if (distributors.isEmpty) {
      logger.w('[UnifiedPush] No distributors available on this device');
      logger.w(
        '[UnifiedPush] User needs to install a UnifiedPush distributor app (e.g., ntfy, NextPush)',
      );
      return;
    }

    // Show dialog for user to select a distributor
    final distributor = await _showDistributorPicker(distributors);
    if (distributor == null) {
      logger.i('[UnifiedPush] User cancelled distributor selection');
      return;
    }

    logger.i('[UnifiedPush] User selected distributor: $distributor');

    // Save the distributor choice
    await UnifiedPush.saveDistributor(distributor);

    // Register with the selected distributor
    logger.i('[UnifiedPush] Registering with selected distributor...');
    await UnifiedPush.register();
  }

  /// Manually trigger distributor selection (e.g., from settings)
  Future<void> selectDistributor() async {
    await _promptUserForDistributor();
  }

  /// Unregister from the current distributor
  Future<void> unregister() async {
    logger.i('[UnifiedPush] Unregistering...');
    await UnifiedPush.unregister();
    _isRegistered = false;
    _currentEndpoint = null;
  }

  /// Show a dialog for user to pick a UnifiedPush distributor
  Future<String?> _showDistributorPicker(List<String> distributors) async {
    final context = Get.context;
    if (context == null) {
      logger.e('[UnifiedPush] Cannot show picker: no context available');
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select Push Distributor'),
          children: distributors.map((distributor) {
            final displayName = _formatDistributorName(distributor);
            return SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop(distributor);
              },
              child: ListTile(
                leading: const Icon(Icons.notifications_active),
                title: Text(displayName),
                subtitle: Text(
                  distributor,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
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

  // ============ UnifiedPush Callbacks ============

  /// Called when a new endpoint is received from the distributor
  /// This endpoint URL should be sent to your application server
  void _onNewEndpoint(PushEndpoint endpoint, String instance) {
    _currentEndpoint = endpoint.url;
    _isRegistered = true;

    logger.i('[UnifiedPush] ✅ New endpoint received!');
    logger.i('[UnifiedPush]   Instance: $instance');
    logger.i('[UnifiedPush]   Endpoint URL: ${endpoint.url}');
    logger.i('[UnifiedPush]   Temporary: ${endpoint.temporary}');
    if (endpoint.pubKeySet != null) {
      logger.i('[UnifiedPush]   Public Key Set available');
    }

    // Sync pubkeys to notification server with the new endpoint
    _syncEndpointToServer();
  }

  /// Sync the UnifiedPush endpoint to notification server
  Future<void> _syncEndpointToServer() async {
    if (_currentEndpoint == null) {
      logger.w('[UnifiedPush] Cannot sync: no endpoint available');
      return;
    }

    try {
      logger.i(
        '[UnifiedPush] Syncing endpoint $_currentEndpoint to notification server...',
      );
      await NotifyService.instance.syncPubkeysToServer(checkUpload: true);
      logger.i('[UnifiedPush] Endpoint synced successfully');
    } catch (e, s) {
      logger.e(
        '[UnifiedPush] Failed to sync endpoint',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Called when registration with a distributor fails
  void _onRegistrationFailed(FailedReason reason, String instance) {
    _isRegistered = false;
    _currentEndpoint = null;

    logger.e('[UnifiedPush] ❌ Registration failed!');
    logger.e('[UnifiedPush]   Instance: $instance');
    logger.e('[UnifiedPush]   Reason: $reason');

    // Provide more details based on the reason
    switch (reason) {
      case FailedReason.network:
        logger.e('[UnifiedPush]   Network error - check internet connection');
      case FailedReason.internalError:
        logger.e('[UnifiedPush]   Internal error in the distributor');
      case FailedReason.actionRequired:
        logger.e('[UnifiedPush]   User action required in distributor app');
      case FailedReason.vapidRequired:
        logger.e('[UnifiedPush]   VAPID key required but not provided');
    }
  }

  /// Called when unregistered from a distributor
  void _onUnregistered(String instance) {
    final oldEndpoint = _currentEndpoint;
    _isRegistered = false;
    _currentEndpoint = null;

    logger.i('[UnifiedPush] Unregistered from instance: $instance');

    // Clear registration from notification server
    if (oldEndpoint != null) {
      _clearEndpointFromServer();
    }
  }

  /// Clear the UnifiedPush endpoint from notification server
  Future<void> _clearEndpointFromServer() async {
    try {
      logger.i('[UnifiedPush] Clearing endpoint from notification server...');
      await NotifyService.instance.clearAll();
      logger.i('[UnifiedPush] Endpoint cleared successfully');
    } catch (e, s) {
      logger.e(
        '[UnifiedPush] Failed to clear endpoint',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Called when the distributor is temporarily unavailable
  void _onTempUnavailable(String instance) {
    logger.w('[UnifiedPush] ⚠️ Distributor temporarily unavailable');
    logger.w('[UnifiedPush]   Instance: $instance');
    logger.w('[UnifiedPush]   Push notifications may be delayed');
  }

  /// Called when a push message is received
  void _onMessage(PushMessage message, String instance) {
    logger.i('[UnifiedPush] 📩 Message received!');
    logger.i('[UnifiedPush]   Instance: $instance');
    logger.i('[UnifiedPush]   Content length: ${message.content.length} bytes');
    logger.d('[UnifiedPush]   Content: ${message.content}');

    // TODO: Process the push message
    // This is where you would handle the incoming notification
    // Example:
    // await _handlePushMessage(message);
  }
}
