import 'package:flutter/material.dart';
import 'package:keychat_ecash/keychat_ecash.dart' show CashuWallet, NwcWallet;
import 'package:keychat_ecash/unified_wallet/index.dart'
    show CashuWallet, NwcWallet;
import 'package:keychat_ecash/unified_wallet/models/cashu_wallet.dart'
    show CashuWallet;
import 'package:keychat_ecash/unified_wallet/models/nwc_wallet.dart'
    show NwcWallet;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart' show Transaction;
import 'package:ndk/ndk.dart' show TransactionResult;

/// Enum representing different wallet protocols/types.
///
/// This enum is used to distinguish between different wallet implementations
/// in the unified wallet architecture. Each protocol has specific capabilities
/// and requirements.
enum WalletProtocol {
  /// Cashu ecash protocol - mint-based ecash transactions
  cashu,

  /// Nostr Wallet Connect - remote Lightning wallet via Nostr protocol
  nwc,

  // Future protocols can be added here:
  // lightning,  // Direct Lightning node connection
  // onchain,    // Bitcoin on-chain wallet
  // lnurl,      // LNURL protocol support
}

/// Abstract base class for all wallet types in the unified wallet architecture.
///
/// This class provides a common interface for different wallet protocols
/// (Cashu, NWC, etc.), enabling the application to work with multiple wallet
/// types through a single consistent API.
///
/// ## Architecture Overview:
///
/// The wallet system uses a layered architecture:
/// ```
/// UI Layer (SelectMintAndNwc, PayInvoice, etc.)
///     ↓
/// Controller Layer (EcashController, UnifiedWalletController)
///     ↓
/// Model Layer (WalletBase → CashuWallet, NwcWallet)
///     ↓
/// Storage Layer (WalletStorage)
/// ```
///
/// ## Implementations:
/// - [CashuWallet]: Cashu ecash protocol wallets
/// - [NwcWallet]: Nostr Wallet Connect wallets
///
/// ## Key Design Principles:
/// 1. **Protocol-agnostic UI**: UI components work with WalletBase
/// 2. **Polymorphic behavior**: Each implementation provides protocol-specific logic
/// 3. **Unified transactions**: All payments return WalletTransactionBase
/// 4. **Single source of truth**: EcashController.selectedWallet
abstract class WalletBase {
  /// Unique identifier for this wallet.
  ///
  /// For Cashu wallets: the mint URL
  /// For NWC wallets: the NWC connection URI
  String get id;

  /// Display name for the wallet (user-defined or derived).
  ///
  /// Used in UI to show a human-readable wallet name
  String get displayName;

  /// The protocol type of this wallet.
  ///
  /// Used to determine wallet capabilities and behavior
  WalletProtocol get protocol;

  /// Current balance in satoshis
  int get balanceSats;

  /// Whether the balance is currently being loaded
  bool get isBalanceLoading;

  /// Icon to display for this wallet type
  IconData get icon;

  /// Color associated with this wallet (for card gradients)
  Color get primaryColor;

  /// Secondary info to display (e.g., mint URL or wallet provider name)
  String get subtitle;

  /// Whether this wallet supports sending payments
  bool get canSend;

  /// Whether this wallet supports receiving payments
  bool get canReceive;

  /// Whether this wallet supports Lightning payments
  bool get supportsLightning;

  /// Raw underlying data (for type-specific operations)
  dynamic get rawData;
}

/// Represents a transaction in a unified format
abstract class WalletTransactionBase {
  /// Unique transaction ID
  String get id;

  String? get walletId;

  /// Amount in satoshis (positive for incoming, negative for outgoing)
  int get amountSats;

  /// Transaction timestamp
  DateTime get timestamp;

  /// Human-readable description
  String? get description;

  /// Transaction status
  WalletTransactionStatus get status;

  /// Whether this is an incoming transaction
  bool get isIncoming;

  /// The protocol this transaction belongs to
  WalletProtocol get protocol;

  /// Raw underlying transaction data
  dynamic get rawData;

  /// Returns the preimage of the payment if available
  String? get preimage;

  /// Returns the fee paid for the payment in sats if available
  int? get fee;

  /// Returns whether the payment was successful
  bool get isSuccess;

  String? get invoice {
    if (rawData is Transaction) {
      return (rawData as Transaction).token;
    } else if (rawData is TransactionResult) {
      return (rawData as TransactionResult).invoice;
    }

    return null;
  }
}

/// Unified transaction status
enum WalletTransactionStatus {
  pending,
  success,
  failed,
  expired,
}
