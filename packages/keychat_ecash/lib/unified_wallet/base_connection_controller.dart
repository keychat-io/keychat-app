import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat/service/wallet_connection_storage.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart'
    show WalletProtocol;

/// Abstract base controller for managing wallet connections (NWC, LND).
///
/// Extracts the common connection lifecycle into a single generic class:
/// loading from storage, connecting, adding/removing, balance refresh, etc.
///
/// Subclasses must implement the protocol-specific hooks marked as abstract.
///
/// [TConnection] – the runtime connection type (e.g. ActiveNwcConnection).
/// [TInfo]       – the parsed connection info type (e.g. NwcConnectionInfo).
abstract class BaseConnectionController<TConnection, TInfo>
    extends GetxController {
  final WalletConnectionStorage storage = WalletConnectionStorage.instance;
  final Map<String, TConnection> connectionMap = {};

  final RxList<TConnection> activeConnections = <TConnection>[].obs;
  final RxBool isInitialized = false.obs;
  final RxInt currentIndex = 0.obs;

  // ---------------------------------------------------------------------------
  // Abstract hooks – subclasses provide protocol-specific behavior
  // ---------------------------------------------------------------------------

  /// The protocol this controller manages.
  WalletProtocol get protocol;

  /// Extract the balance (in sats) from a single [connection].
  int balanceFromConnection(TConnection connection);

  /// Parse a decrypted URI into the protocol-specific info object.
  TInfo parseUri(String uri, {String? name});

  /// Extract a non-secret identifier from the parsed [info] object.
  String identifierFromInfo(TInfo info);

  /// Extract the original URI string from the parsed [info] object.
  String uriFromInfo(TInfo info);

  /// Establish a live connection and return a [TConnection].
  ///
  /// Returns null if the connection failed (subclass handles logging).
  Future<TConnection?> connect(
    TInfo info, {
    required String identifier,
    int? walletConnectionId,
  });

  /// Close/dispose a single connection's underlying resources.
  void closeConnection(TConnection connection);

  /// Refresh the balance for a single [connection] from the remote source.
  ///
  /// Implementations should mutate [connection] in-place (set cached balance).
  Future<void> refreshBalance(TConnection connection);

  /// Rebuild the connection info with an updated name.
  TInfo updateInfoName(TConnection connection, String? newName);

  /// Set the info on an existing connection object.
  void setConnectionInfo(TConnection connection, TInfo info);

  /// Get the storage ID from a connection (may be null for unsaved connections).
  int? getStorageId(TConnection connection);

  // ---------------------------------------------------------------------------
  // Shared implementation
  // ---------------------------------------------------------------------------

  /// Total balance across all active connections in sats.
  int get totalSats {
    return activeConnections.fold<int>(
      0,
      (sum, connection) => sum + balanceFromConnection(connection),
    );
  }

  /// Wait for initialization with a 10-second timeout.
  Future<bool> waitForLoading() async {
    if (isInitialized.value) return true;

    final completer = Completer<bool>();
    late Worker worker;
    Timer? timeoutTimer;

    worker = ever(isInitialized, (bool value) {
      if (value && !completer.isCompleted) {
        timeoutTimer?.cancel();
        worker.dispose();
        completer.complete(true);
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        worker.dispose();
        completer.complete(false);
      }
    });

    return completer.future;
  }

  /// Load all saved connections from Isar, decrypt, connect, refresh balances.
  Future<void> loadConnections() async {
    try {
      final saved = await storage.getAll(protocol);
      for (final wc in saved) {
        try {
          final uri = await storage.getDecryptedUri(wc);
          final info = parseUri(uri, name: wc.name);
          final connection = await connect(
            info,
            identifier: wc.identifier,
            walletConnectionId: wc.id,
          );
          if (connection != null) {
            connectionMap[uri] = connection;
          }
        } catch (e) {
          logger.e('Failed to load ${protocol.name} '
              'connection ${wc.identifier}: $e');
        }
      }
      refreshList();
      await refreshAllBalances();
    } finally {
      isInitialized.value = true;
    }
  }

  /// Sync the observable list from the internal map.
  void refreshList() {
    activeConnections.value = connectionMap.values.toList();
    logger.i('Loaded ${activeConnections.length} ${protocol.name} connections');
  }

  /// Refresh balances for the given [connections], or all if null.
  ///
  /// All connections are refreshed in parallel. The method returns as soon as
  /// the **first** connection successfully updates its balance (race mode),
  /// so the UI can display a result without waiting for slower relays.
  /// Remaining connections continue refreshing in the background.
  /// Falls back to a 5-second timeout if no connection succeeds.
  Future<void> refreshAllBalances([
    List<TConnection>? connections,
    Duration timeout = const Duration(seconds: 10),
  ]) async {
    final targets = connections ?? activeConnections.toList();
    if (targets.isEmpty) return;

    // Completer that resolves when the first balance succeeds
    final firstDone = Completer<void>();
    var doneCount = 0;

    for (final connection in targets) {
      unawaited(() async {
        try {
          await refreshBalance(connection);
          activeConnections.refresh();
          // First success → unblock the caller
          if (!firstDone.isCompleted) firstDone.complete();
        } catch (e) {
          logger.e('Error refreshing ${protocol.name} balance: $e');
        } finally {
          doneCount++;
          // If all finished (all failed) and nobody completed yet, unblock
          if (doneCount >= targets.length && !firstDone.isCompleted) {
            firstDone.complete();
          }
        }
      }());
    }

    // Wait for the first success or all failures, capped by timeout
    await firstDone.future.timeout(
      timeout,
      onTimeout: () {
        logger.d('${protocol.name} balance refresh timed out after $timeout');
      },
    );

    activeConnections.refresh();
  }

  /// Reload everything: close connections, clear state, load from storage.
  Future<void> reloadConnections() async {
    isInitialized.value = false;
    try {
      connectionMap.values.forEach(closeConnection);
      connectionMap.clear();
      activeConnections.clear();
      await loadConnections();
    } catch (e) {
      logger.e('Failed to reload ${protocol.name} connections: $e');
      await EasyLoading.showError('Failed to reload connections');
    } finally {
      isInitialized.value = true;
    }
  }

  /// Add a new connection from a raw URI string.
  ///
  /// Parses the URI, extracts the identifier, persists to storage, connects.
  Future<void> addConnection(String uri) async {
    if (connectionMap.containsKey(uri)) {
      throw Exception('Connection already active');
    }

    final info = parseUri(uri);
    final identifier = identifierFromInfo(info);

    final wc = await storage.add(
      protocol: protocol,
      identifier: identifier,
      uri: uri,
    );

    final connection = await connect(
      info,
      identifier: identifier,
      walletConnectionId: wc.id,
    );
    if (connection != null) {
      connectionMap[uri] = connection;
    }
    refreshList();
  }

  /// Update the user-visible name for a connection identified by [uri].
  Future<void> updateConnectionName(String uri, String newName) async {
    try {
      final connection = connectionMap[uri];
      if (connection == null) throw Exception('Connection not found');

      final id = getStorageId(connection);
      if (id == null) throw Exception('Connection has no storage ID');

      final resolvedName = newName.isEmpty ? null : newName;
      if (resolvedName != null) {
        await storage.update(id, name: resolvedName);
      } else {
        await storage.update(id, clearName: true);
      }

      final updatedInfo = updateInfoName(connection, resolvedName);
      setConnectionInfo(connection, updatedInfo);
      refreshList();
      await EasyLoading.showSuccess('Connection name updated');
    } catch (e) {
      await EasyLoading.showError(e.toString());
    }
  }

  /// Delete a connection identified by [uri].
  Future<bool> deleteConnection(String uri) async {
    try {
      final connection = connectionMap[uri];
      if (connection != null) {
        closeConnection(connection);

        final id = getStorageId(connection);
        if (id != null) {
          await storage.delete(id);
        }
      }

      connectionMap.remove(uri);
      refreshList();
      return true;
    } catch (e) {
      await EasyLoading.showError(e.toString());
      return false;
    }
  }

  /// Look up an active connection by its URI key.
  ///
  /// Throws if not found.
  TConnection getConnectionByUri(String uri) {
    final connection = connectionMap[uri];
    if (connection == null) {
      throw Exception('${protocol.name} connection not found: $uri');
    }
    return connection;
  }
}
