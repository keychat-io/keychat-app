import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:keychat/app.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_nwc/active_nwc_connection.dart';
import 'package:ndk/domain_layer/usecases/nwc/consts/transaction_type.dart';
import 'package:ndk/ndk.dart';

/// NWC (Nostr Wallet Connect) wallet implementation
class NwcWallet extends WalletBase {
  NwcWallet({required this.connection});

  final ActiveNwcConnection connection;

  @override
  String get id => connection.info.uri;

  @override
  String get displayName =>
      connection.info.name ?? _extractWalletName(connection.info.uri);

  @override
  WalletProtocol get protocol => WalletProtocol.nwc;

  @override
  int get balanceSats {
    if (connection.balance == null) return 0;
    return (connection.balance!.balanceMsats / 1000).floor();
  }

  @override
  bool get isBalanceLoading => connection.balance == null;

  @override
  IconData get icon => CupertinoIcons.bitcoin_circle;

  @override
  Color get primaryColor => KeychatGlobal.bitcoinColor;

  @override
  String get subtitle => _extractWalletName(connection.info.uri);

  @override
  bool get canSend => balanceSats > 0;

  @override
  bool get canReceive => true;

  @override
  bool get supportsLightning => true;

  @override
  ActiveNwcConnection get rawData => connection;

  /// Max spending budget (if available)
  int? get maxBudget => connection.balance?.maxAmount;

  /// Extract wallet name from NWC URI
  String _extractWalletName(String uri) {
    try {
      // NWC URIs typically contain relay info
      final decoded = Uri.parse(uri.replaceFirst('nostr+walletconnect://', ''));
      final res = decoded.host.isNotEmpty
          ? decoded.host
          : decoded.queryParameters['lud16'];
      return res ?? 'NWC Wallet';
    } catch (_) {
      return 'NWC Wallet';
    }
  }
}

/// NWC transaction wrapper
class NwcWalletTransaction extends WalletTransactionBase {
  NwcWalletTransaction({required this.transaction, this.walletId});

  final TransactionResult transaction;

  @override
  final String? walletId;

  @override
  String get id => transaction.paymentHash;

  @override
  int get amountSats {
    // NWC amounts are in millisats
    final amount = (transaction.amount / 1000).floor();
    return transaction.type == TransactionType.incoming.name ? amount : -amount;
  }

  @override
  DateTime get timestamp {
    if (transaction.settledAt != null) {
      return DateTime.fromMillisecondsSinceEpoch(transaction.settledAt! * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(transaction.createdAt * 1000);
  }

  @override
  String? get description => transaction.description;

  @override
  WalletTransactionStatus get status {
    // NWC doesn't have explicit status, infer from settledAt
    if (transaction.settledAt != null) {
      return WalletTransactionStatus.success;
    }
    return WalletTransactionStatus.pending;
  }

  @override
  bool get isIncoming => transaction.type == TransactionType.incoming.name;

  @override
  WalletProtocol get protocol => WalletProtocol.nwc;

  @override
  TransactionResult get rawData => transaction;

  @override
  String? get preimage => transaction.preimage;

  @override
  int? get fee =>
      transaction.feesPaid != null ? transaction.feesPaid! ~/ 1000 : null;

  @override
  bool get isSuccess => true; // NWC payment is always success if returned
}
