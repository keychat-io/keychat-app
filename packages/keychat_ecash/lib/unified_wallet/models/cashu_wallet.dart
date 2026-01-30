import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:keychat/global.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

/// Cashu wallet implementation
class CashuWallet extends WalletBase {
  CashuWallet({
    required this.mintBalance,
    this.supportsMint = true,
    this.supportsMelt = true,
  });

  final MintBalanceClass mintBalance;
  final bool supportsMint;
  final bool supportsMelt;

  @override
  String get id => mintBalance.mint;

  @override
  String get displayName => _extractMintName(mintBalance.mint);

  @override
  WalletProtocol get protocol => WalletProtocol.cashu;

  @override
  int get balanceSats => mintBalance.balance;

  @override
  bool get isBalanceLoading => false;

  @override
  IconData get icon => CupertinoIcons.bitcoin_circle;

  @override
  Color get primaryColor => KeychatGlobal.bitcoinColor;

  @override
  String get subtitle => mintBalance.mint;

  @override
  bool get canSend => supportsMelt && balanceSats > 0;

  @override
  bool get canReceive => supportsMint;

  @override
  bool get supportsLightning => supportsMelt;

  @override
  MintBalanceClass get rawData => mintBalance;

  /// Extract a friendly name from mint URL
  String _extractMintName(String mintUrl) {
    try {
      final uri = Uri.parse(mintUrl);
      return uri.host;
    } catch (_) {
      return mintUrl;
    }
  }
}

class CashuWalletTransaction extends WalletTransactionBase {
  CashuWalletTransaction({required this.transaction, this.walletId});

  final Transaction transaction;

  @override
  String? walletId;

  @override
  String get id => transaction.id;

  @override
  int get amountSats {
    final amount = transaction.amount.toInt();
    return transaction.io == TransactionDirection.incoming ? amount : -amount;
  }

  @override
  DateTime get timestamp =>
      DateTime.fromMillisecondsSinceEpoch(transaction.timestamp.toInt() * 1000);

  @override
  String? get description => transaction.metadata['memo'];

  @override
  WalletTransactionStatus get status {
    switch (transaction.status) {
      case TransactionStatus.pending:
        return WalletTransactionStatus.pending;
      case TransactionStatus.success:
        return WalletTransactionStatus.success;
      case TransactionStatus.failed:
        return WalletTransactionStatus.failed;
      case TransactionStatus.expired:
        return WalletTransactionStatus.expired;
    }
  }

  @override
  bool get isIncoming => transaction.io == TransactionDirection.incoming;

  @override
  WalletProtocol get protocol => WalletProtocol.cashu;

  @override
  Transaction get rawData => transaction;

  @override
  String? get preimage => transaction.token;

  @override
  int? get fee => transaction.fee.toInt();

  @override
  bool get isSuccess => transaction.status == TransactionStatus.success;

  @override
  String get paymentHash => transaction.id;
}
