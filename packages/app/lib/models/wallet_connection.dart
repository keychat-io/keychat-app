import 'package:equatable/equatable.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart'
    show WalletProtocol;

part 'wallet_connection.g.dart';

/// Isar model for persisting NWC and LND wallet connections.
///
/// Sensitive fields (the full URI containing secrets) are AES-encrypted
/// before storage. The [identifier] field is a non-secret dedup key
/// (wallet pubkey for NWC, host:port for LND).
@Collection(ignore: {'props'})
// Equatable requires mutable fields for Isar compatibility.
// ignore: must_be_immutable
class WalletConnection extends Equatable {
  WalletConnection();

  WalletConnection.create({
    required this.protocol,
    required this.identifier,
    required this.encryptedUri,
    this.name,
    this.weight = 0,
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  Id id = Isar.autoIncrement;

  @Index()
  @Enumerated(EnumType.ordinal32)
  late WalletProtocol protocol;

  /// Non-secret unique identifier for dedup/lookup.
  ///
  /// NWC: wallet pubkey from the URI host.
  /// LND: host:port.
  @Index(unique: true, composite: [CompositeIndex('protocol')])
  late String identifier;

  /// AES-encrypted full URI (contains secrets like NWC secret key or LND macaroon).
  late String encryptedUri;

  /// User-defined wallet name.
  String? name;

  /// Weight for sorting (higher = more important).
  int weight = 0;

  late DateTime createdAt;
  late DateTime updatedAt;

  @override
  List<Object?> get props => [id, protocol, identifier];
}
