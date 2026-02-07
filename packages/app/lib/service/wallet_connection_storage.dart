import 'package:isar_community/isar.dart';
import 'package:keychat/models/db_provider.dart';
import 'package:keychat/models/wallet_connection.dart';
import 'package:keychat/service/wallet_connection_crypto.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart'
    show WalletProtocol;

/// Unified CRUD storage for NWC and LND wallet connections, backed by Isar.
///
/// Sensitive URIs are encrypted via [WalletConnectionCrypto] before persisting.
class WalletConnectionStorage {
  WalletConnectionStorage._();
  static WalletConnectionStorage? _instance;
  static WalletConnectionStorage get instance =>
      _instance ??= WalletConnectionStorage._();

  final WalletConnectionCrypto _crypto = WalletConnectionCrypto.instance;

  Isar get _db => DBProvider.database;

  /// Returns all connections for the given [protocol], ordered by weight desc.
  Future<List<WalletConnection>> getAll(
      WalletProtocol protocol) async {
    return _db.walletConnections
        .filter()
        .protocolEqualTo(protocol)
        .sortByWeightDesc()
        .findAll();
  }

  /// Adds a new connection.
  ///
  /// [identifier] is the non-secret dedup key (wallet pubkey for NWC, host:port for LND).
  /// [uri] is the full URI that will be encrypted before storage.
  /// Duplicate check uses both [protocol] and [identifier] to avoid cross-protocol
  /// collisions (e.g. an NWC wallet pubkey that happens to match an LND host:port).
  Future<WalletConnection> add({
    required WalletProtocol protocol,
    required String identifier,
    required String uri,
    String? name,
    int weight = 0,
  }) async {
    // Check for duplicates within the same protocol
    final existing = await _db.walletConnections
        .filter()
        .protocolEqualTo(protocol)
        .and()
        .identifierEqualTo(identifier)
        .findFirst();
    if (existing != null) {
      throw Exception('Connection with this identifier already exists');
    }

    final encryptedUri = await _crypto.encryptText(uri);
    final connection = WalletConnection.create(
      protocol: protocol,
      identifier: identifier,
      encryptedUri: encryptedUri,
      name: name,
      weight: weight,
    );

    await _db.writeTxn(() async {
      await _db.walletConnections.put(connection);
    });
    return connection;
  }

  /// Updates mutable fields of an existing connection.
  ///
  /// Pass empty string for [name] to clear it (set to null).
  /// Pass a non-empty string to set a new name.
  /// Omit [name] to leave it unchanged.
  Future<void> update(
    int id, {
    String? name,
    bool clearName = false,
    int? weight,
    String? uri,
  }) async {
    final connection = await _db.walletConnections.get(id);
    if (connection == null) {
      throw Exception('Connection not found');
    }

    if (clearName) {
      connection.name = null;
    } else if (name != null) {
      connection.name = name;
    }
    if (weight != null) connection.weight = weight;
    if (uri != null) {
      connection.encryptedUri = await _crypto.encryptText(uri);
    }
    connection.updatedAt = DateTime.now();

    await _db.writeTxn(() async {
      await _db.walletConnections.put(connection);
    });
  }

  /// Deletes a connection by ID.
  Future<void> delete(int id) async {
    await _db.writeTxn(() async {
      await _db.walletConnections.delete(id);
    });
  }

  /// Decrypts and returns the full URI for a connection.
  ///
  /// For Cashu mints, the URI is stored in plaintext (no secrets to protect).
  Future<String> getDecryptedUri(WalletConnection connection) async {
    if (connection.protocol == WalletProtocol.cashu) {
      return connection.encryptedUri;
    }
    return _crypto.decryptText(connection.encryptedUri);
  }

  /// Finds a connection by its identifier.
  Future<WalletConnection?> findByIdentifier(String identifier) async {
    return _db.walletConnections
        .filter()
        .identifierEqualTo(identifier)
        .findFirst();
  }

  /// Adds a Cashu mint to the registry (plaintext, no encryption needed).
  ///
  /// Returns the existing connection if one with the same [mintUrl] already exists.
  Future<WalletConnection> addCashuMint(String mintUrl,
      {String? name}) async {
    final existing = await findByIdentifier(mintUrl);
    if (existing != null) return existing;

    final connection = WalletConnection.create(
      protocol: WalletProtocol.cashu,
      identifier: mintUrl,
      encryptedUri: mintUrl, // plaintext — mint URLs are not secret
      name: name,
    );
    await _db.writeTxn(() async {
      await _db.walletConnections.put(connection);
    });
    return connection;
  }

  /// Deletes a Cashu mint from the registry by its URL.
  Future<void> deleteCashuMint(String mintUrl) async {
    final connection = await findByIdentifier(mintUrl);
    if (connection != null) {
      await delete(connection.id);
    }
  }
}
