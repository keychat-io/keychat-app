import 'package:flutter/material.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart' show Transaction;
import 'package:ndk/ndk.dart' show TransactionResult;

/// Enum representing different wallet protocols/types
enum WalletProtocol {
  cashu,
  nwc,
  // Future protocols can be added here:
  // lightning,
  // onchain,
  // lnurl,
}

/// Abstract base class for all wallet types
/// This provides a unified interface for different wallet protocols
abstract class WalletBase {
  /// Unique identifier for this wallet
  String get id;

  /// Display name for the wallet (user-defined or derived)
  String get displayName;

  /// The protocol type of this wallet
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
