import 'dart:async';
import 'dart:convert';

import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:unifiedpush/unifiedpush.dart';
import 'package:unifiedpush_platform_interface/unifiedpush_platform_interface.dart'
    show LinuxOptions;
import 'package:unifiedpush_storage_shared_preferences/storage.dart';

class UnifiedPushService {
  // Singleton pattern
  UnifiedPushService._();
  static UnifiedPushService? _instance;
  static UnifiedPushService get instance =>
      _instance ??= UnifiedPushService._();

  static const pushInstance = 'default';

  /// Storage key for persisting endpoint
  static const _endpointStorageKey = 'unifiedpush_endpoint';

  /// Current push endpoint URL (received from distributor)
  String? _currentEndpoint;
  String? p256dh;
  String? auth;

  String? get currentEndpoint => _currentEndpoint;

  /// Whether the service has been initialized
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Whether we are registered with a distributor
  bool _isRegistered = false;
  bool get isRegistered => _isRegistered;
  String? oldToken;

  /// Load saved endpoint from storage
  Future<void> _loadSavedEndpoint() async {
    final endpoint = await Storage.getLocalStorageMap(_endpointStorageKey);
    if (endpoint.isNotEmpty) {
      logger.i('[UnifiedPush] Loaded saved endpoint: $endpoint');
      _currentEndpoint = endpoint['url'] as String?;
      p256dh = endpoint['p256dh'] as String?;
      auth = endpoint['auth'] as String?;
      return;
    }
  }

  /// Save endpoint to storage
  Future<void> _saveEndpoint(PushEndpoint? endpoint) async {
    try {
      if (endpoint != null) {
        _currentEndpoint = endpoint.url;
        p256dh = endpoint.pubKeySet?.pubKey;
        auth = endpoint.pubKeySet?.auth;
        await Storage.setString(
          _endpointStorageKey,
          jsonEncode({
            'url': endpoint.url,
            'p256dh': endpoint.pubKeySet?.pubKey ?? '',
            'auth': endpoint.pubKeySet?.auth ?? '',
          }),
        );
        logger.i('[UnifiedPush] Saved endpoint to storage');
      } else {
        await Storage.remove(_endpointStorageKey);
        logger.i('[UnifiedPush] Cleared endpoint from storage');
      }
    } catch (e, s) {
      logger.e(
        '[UnifiedPush] Failed to save endpoint',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Reset initialization state to allow re-initialization
  /// Call this when switching from FCM to UnifiedPush
  void resetInitState() {
    _isInitialized = false;
    _isRegistered = false;
    logger.i('[UnifiedPush] Init state reset');
  }

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
  /// [autoPromptDistributor] - Whether to automatically show distributor picker
  ///   if no default distributor is found. Set to false when called from settings
  ///   page where the page handles distributor selection itself.
  Future<void> init({
    List<String> args = const [],
    bool autoPromptDistributor = true,
    String? lastUsedToken,
  }) async {
    // UnifiedPush only supports Android and Linux
    if (!GetPlatform.isAndroid && !GetPlatform.isLinux) {
      return;
    }

    oldToken = lastUsedToken;

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
    await _loadSavedEndpoint();

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
      _isRegistered = true;
      await UnifiedPush.register();
    }
  }

  /// Switch to a different distributor
  /// Returns the new endpoint URL or null if failed
  Future<String?> switchDistributor(String newDistributor) async {
    final currentDistributor = await getCurrentDistributor();

    logger.i(
      '[UnifiedPush] Switching distributor: $currentDistributor -> $newDistributor',
    );

    // If switching to same distributor and already have endpoint, return it
    if (currentDistributor == newDistributor && _currentEndpoint != null) {
      logger.i(
        '[UnifiedPush] Already registered with this distributor, returning existing endpoint',
      );
      return _currentEndpoint;
    }

    // Unregister from current distributor if switching to a different one
    if (_isRegistered && currentDistributor != newDistributor) {
      logger.i('[UnifiedPush] Unregistering from current distributor...');
      await unregister();
      // Wait a bit for unregister to propagate
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    // Save and register with new distributor
    logger.i('[UnifiedPush] Saving distributor: $newDistributor');
    await UnifiedPush.saveDistributor(newDistributor);

    logger.i('[UnifiedPush] Registering with new distributor...');
    await UnifiedPush.register();
    await Future.delayed(const Duration(seconds: 1));
    return _currentEndpoint;
  }

  /// Unregister from the current distributor

  Future<void> unregister() async {
    await UnifiedPush.unregister();
    _isRegistered = false;
    _currentEndpoint = null;
  }

  // ============ UnifiedPush Callbacks ============

  /// Called when a new endpoint is received from the distributor
  /// This endpoint URL should be sent to your application server
  Future<void> _onNewEndpoint(PushEndpoint endpoint, String instance) async {
    NotifyService.instance.oldToken = await NotifyService.instance.deviceId;
    _currentEndpoint = endpoint.url;
    _isRegistered = true;

    loggerNoLine
      ..i('[UnifiedPush] ✅ New endpoint received!')
      ..i('[UnifiedPush]   Instance: $instance')
      ..i('[UnifiedPush]   Endpoint URL: ${endpoint.url}')
      ..i('[UnifiedPush]   pubKeySet: ${endpoint.pubKeySet?.pubKey}')
      ..i('[UnifiedPush]   pubKeySet: ${endpoint.pubKeySet?.auth}');
    await _saveEndpoint(endpoint);
    EasyThrottle.throttle(
      'unifiedpush_sync:${endpoint.url}',
      const Duration(seconds: 1),
      () async {
        await _syncEndpointToServer();
      },
    );
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
  Future<void> _onRegistrationFailed(
    FailedReason reason,
    String instance,
  ) async {
    _isRegistered = false;

    logger.e('[UnifiedPush] ❌ Registration failed!');
    logger.e('[UnifiedPush]   Instance: $instance');
    logger.e('[UnifiedPush]   Reason: $reason');

    var reasonMsg = '';
    switch (reason) {
      case FailedReason.network:
        logger.e('[UnifiedPush]   Network error - check internet connection');
        reasonMsg = 'Network error, please check your internet connection';
      case FailedReason.internalError:
        logger.e('[UnifiedPush]   Internal error in the distributor');
        reasonMsg = 'Internal error in the distributor';
      case FailedReason.actionRequired:
        logger.e('[UnifiedPush]   User action required in distributor app');
        reasonMsg = 'Action required in the distributor app';
      case FailedReason.vapidRequired:
        logger.e('[UnifiedPush]   VAPID key required but not provided');
        reasonMsg = 'VAPID key required but not provided';
    }

    final context = Get.context;
    if (context != null && reasonMsg.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Push Registration Failed'),
          content: Text(reasonMsg),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Called when unregistered from a distributor
  Future<void> _onUnregistered(String instance) async {
    logger.i('[UnifiedPush] Unregistered from instance: $instance');
    _isRegistered = false;
    await _saveEndpoint(null);
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
