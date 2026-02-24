import 'package:flutter/material.dart';

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

  /// LND Lightning Network Daemon - direct Lightning node connection
  lnd,

  /// Lightning Pub - public Lightning wallet service
  lightningPub
}

/// Abstract base class for all wallet types in the unified wallet architecture.
///
/// This class provides a common interface for different wallet protocols
/// (Cashu, NWC, LND), enabling the application to work with multiple wallet
/// types through a single consistent API.
///
/// ## Architecture Overview
///
/// The unified wallet system manages three distinct wallet protocols through
/// a common abstraction layer:
///
/// ### Supported Protocols
///
/// - **Cashu** – Mint-based ecash. Tokens are stored locally; the mint acts as
///   a blind-signing server. Supports both ecash token transfers and Lightning
///   melt/mint operations.
/// - **NWC (Nostr Wallet Connect)** – Remote Lightning wallet control via the
///   Nostr protocol (NIP-47). Commands (pay_invoice, make_invoice, etc.) are
///   sent as encrypted Nostr events to a wallet service.
/// - **LND (Lightning Network Daemon)** – Direct REST connection to an LND
///   node via lndconnect:// URIs. Provides full Lightning capabilities
///   including channel management.
///
/// ### Layered Architecture
///
/// ```text
/// ┌─────────────────────────────────────────────────┐
/// │  UI Layer                                       │
/// │  BitcoinWalletMain, PayInvoice, CreateInvoice   │
/// └──────────────────┬──────────────────────────────┘
///                    │
/// ┌──────────────────▼──────────────────────────────┐
/// │  Controller Layer                               │
/// │  UnifiedWalletController, EcashController        │
/// └──────────────────┬──────────────────────────────┘
///                    │
/// ┌──────────────────▼──────────────────────────────┐
/// │  Provider Layer                                 │
/// │  WalletProvider interface                       │
/// │  ├─ CashuWalletProvider                         │
/// │  ├─ NwcWalletProvider                           │
/// │  └─ LndWalletProvider                           │
/// └──────────────────┬──────────────────────────────┘
///                    │
/// ┌──────────────────▼──────────────────────────────┐
/// │  Model Layer                                    │
/// │  WalletBase (this class)                        │
/// │  ├─ CashuWallet                                 │
/// │  ├─ NwcWallet                                   │
/// │  └─ LndWallet                                   │
/// └──────────────────┬──────────────────────────────┘
///                    │
/// ┌──────────────────▼──────────────────────────────┐
/// │  Protocol Controllers                           │
/// │  EcashController, NwcController, LndController  │
/// └──────────────────┬──────────────────────────────┘
///                    │
/// ┌──────────────────▼──────────────────────────────┐
/// │  Storage Layer                                  │
/// │  WalletConnectionStorage (Isar DB)              │
/// └─────────────────────────────────────────────────┘
/// ```
///
/// ### Balance Update Flow
///
/// Each `WalletProvider` registers a reactive listener via
/// `WalletProvider.setOnWalletsChanged` that fires whenever the underlying
/// protocol controller's data changes:
///
/// - **CashuWalletProvider** listens to `EcashController.mintBalances`
/// - **NwcWalletProvider** listens to `NwcController.activeConnections`
/// - **LndWalletProvider** listens to `LndController.activeConnections`
///
/// When a change is detected, the provider rebuilds its wallet list and
/// invokes the callback. `UnifiedWalletController` receives the updated
/// wallets and patches them into the unified `wallets` list in-place,
/// triggering reactive UI updates without a full reload.
///
/// ### Progressive Loading
///
/// `UnifiedWalletController.loadAllWallets` loads all providers in parallel
/// via `Future.wait`. As each provider completes, its wallets are merged
/// into the unified list immediately, so wallet cards appear progressively
/// in the UI rather than waiting for all protocols to finish.
///
/// ## Implementations
/// - [CashuWallet]: Cashu ecash protocol wallets
/// - [NwcWallet]: Nostr Wallet Connect wallets
/// - [LndWallet]: LND Lightning Network wallets
///
/// ## Key Design Principles
/// 1. **Protocol-agnostic UI**: UI components work with WalletBase
/// 2. **Polymorphic behavior**: Each implementation provides protocol-specific logic
/// 3. **Unified transactions**: All payments return [WalletTransactionBase]
/// 4. **Reactive updates**: Provider callbacks push changes to the controller
/// 5. **Progressive loading**: Wallets appear as each provider completes
abstract class WalletBase {
  /// Non-secret unique identifier for this wallet.
  ///
  /// For Cashu wallets: the mint URL (not secret)
  /// For NWC wallets: the wallet pubkey (non-secret part of the NWC URI)
  /// For LND wallets: host:port (non-secret part of the lndconnect URI)
  ///
  /// This value is safe to persist, log, and display in the UI.
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

  /// Returns the settings/detail page widget for this wallet.
  Widget settingsPage();
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

  String get paymentHash;

  /// Returns the fee paid for the payment in sats if available
  int? get fee;

  /// Returns whether the payment was successful
  bool get isSuccess;

  /// Returns the invoice/token string for this transaction if available.
  String? get invoice;

  /// Navigates to the appropriate transaction detail page.
  void navigateToTransactionDetail({String? walletId});
}

/// Unified transaction status
enum WalletTransactionStatus {
  pending,
  success,
  failed,
  expired,
}
