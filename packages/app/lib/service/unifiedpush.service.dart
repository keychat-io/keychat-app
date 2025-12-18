import 'dart:async';
import 'dart:convert';

import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat/global.dart' show KeychatGlobal;
import 'package:keychat/service/local_notification_service.dart';
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

  static const localInstance = 'Keychat';
  PushEndpoint? currentEndpoint;
  String? p256dh;
  String? auth;
  bool isBackground = false;

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
  }) async {
    // UnifiedPush only supports Android and Linux
    if (!GetPlatform.isAndroid && !GetPlatform.isLinux) {
      return;
    }
    debugPrint('[UnifiedPush] Starting initialization...');

    // Configure Linux options if on Linux platform
    LinuxOptions? linuxOptions;
    final isBackground = args.contains('--unifiedpush-bg');
    if (GetPlatform.isLinux) {
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
      onUnregistered: onUnregistered,
      onMessage: _onMessage,
      onTempUnavailable: _onTempUnavailable,
      linuxOptions: linuxOptions,
    );

    debugPrint(
      '[UnifiedPush] Initialized. Already registered: $alreadyRegistered',
    );
    if (alreadyRegistered) {
      await UnifiedPush.register(instance: localInstance);
    }
  }

  void onUnregistered(String instance) {
    if (instance != localInstance) {
      return;
    }
    debugPrint('unregistered ${currentEndpoint?.url}');
    currentEndpoint = null;
  }

  /// Switch to a different distributor
  /// Returns the new endpoint URL or null if failed
  Future<PushEndpoint?> switchDistributor(String newDistributor) async {
    final currentDistributor = await getCurrentDistributor();

    debugPrint(
      '[UnifiedPush] Switching distributor: $currentDistributor -> $newDistributor',
    );

    // If switching to same distributor and already have endpoint, return it
    if (currentDistributor == newDistributor && currentEndpoint != null) {
      return currentEndpoint;
    }

    // Unregister from current distributor if switching to a different one
    if (currentDistributor != newDistributor) {
      debugPrint('[UnifiedPush] Unregistering from current distributor...');
      await unregister();
      // Wait a bit for unregister to propagate
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    // Save and register with new distributor
    debugPrint('[UnifiedPush] Saving distributor: $newDistributor');
    await UnifiedPush.saveDistributor(newDistributor);

    debugPrint('[UnifiedPush] Registering with new distributor...');
    await UnifiedPush.register(instance: localInstance);
    await Future.delayed(const Duration(seconds: 1));
    return currentEndpoint;
  }

  /// Unregister from the current distributor

  Future<void> unregister() async {
    if (!(GetPlatform.isAndroid || GetPlatform.isLinux)) {
      return;
    }
    await UnifiedPush.unregister();
  }

  /// Get current endpoint with retry mechanism
  /// Attempts to get the endpoint every 1 second, up to 5 times
  /// Returns the endpoint if found, null otherwise
  Future<PushEndpoint?> getCurrentEndpointWithRetry({
    int maxAttempts = 5,
    Duration retryInterval = const Duration(seconds: 1),
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      debugPrint(
        '[UnifiedPush] Attempting to get endpoint (attempt $attempt/$maxAttempts)...',
      );

      if (currentEndpoint != null) {
        debugPrint('[UnifiedPush] Endpoint found: ${currentEndpoint!.url}');
        return currentEndpoint;
      }

      if (attempt < maxAttempts) {
        debugPrint(
          '[UnifiedPush] Endpoint not available, waiting ${retryInterval.inSeconds}s...',
        );
        await Future.delayed(retryInterval);
      }
    }
    return null;
  }

  // ============ UnifiedPush Callbacks ============

  /// Called when a new endpoint is received from the distributor
  /// This endpoint URL should be sent to your application server
  Future<void> _onNewEndpoint(PushEndpoint endpoint, String instance) async {
    if (instance != localInstance) {
      return;
    }
    if (endpoint.url == currentEndpoint?.url) {
      debugPrint('Endpoint url not changed! ${endpoint.url}');
      if (endpoint.pubKeySet?.pubKey == null) return;
      if (endpoint.pubKeySet?.pubKey == currentEndpoint?.pubKeySet?.pubKey) {
        return;
      }
    }
    currentEndpoint = endpoint;
    if (isBackground) return;
    NotifyService.instance.oldToken = await NotifyService.instance.deviceId;
    debugPrint('[UnifiedPush]   Endpoint URL: ${endpoint.url}');
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
    if (currentEndpoint == null) {
      debugPrint('[UnifiedPush] Cannot sync: no endpoint available');
      return;
    }

    try {
      debugPrint(
        '[UnifiedPush] Syncing endpoint ${currentEndpoint!.url} to notification server...',
      );
      await NotifyService.instance.syncPubkeysToServer(checkUpload: true);
      debugPrint('[UnifiedPush] Endpoint synced successfully');
    } catch (e, s) {
      debugPrint('[UnifiedPush] Failed to sync endpoint');
    }
  }

  /// Called when registration with a distributor fails
  Future<void> _onRegistrationFailed(
    FailedReason reason,
    String instance,
  ) async {
    if (instance != localInstance) {
      return;
    }
    currentEndpoint = null;
    debugPrint('[UnifiedPush] ❌ Registration failed! $reason');

    var reasonMsg = '';
    switch (reason) {
      case FailedReason.network:
        reasonMsg = 'Network error, please check your internet connection';
      case FailedReason.internalError:
        reasonMsg = 'Internal error in the distributor';
      case FailedReason.actionRequired:
        reasonMsg = 'Action required in the distributor app';
      case FailedReason.vapidRequired:
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

  /// Called when the distributor is temporarily unavailable
  void _onTempUnavailable(String instance) {
    debugPrint('[UnifiedPush] _onTempUnavailable  Instance: $instance');
  }

  /// Called when a push message is received
  Future<void> _onMessage(PushMessage message, String instance) async {
    if (instance != KeychatGlobal.appName) {
      return;
    }
    String? id;
    try {
      final payload = utf8.decode(message.content);
      final data = jsonDecode(payload) as Map<String, dynamic>;
      id = data['id'] as String?;
      debugPrint('[UnifiedPush] $instance 📩 : $payload');
    } catch (e) {
      debugPrint(
        "Couldn't decrypt content (decrypted=${message.decrypted}): $e",
      );
    }
    await LocalNotificationService().showNotification(
      id: DateTime.now().microsecondsSinceEpoch % 100000000,
      title: '📩 Keychat',
      body: id ?? 'New Message',
    );
  }
}
