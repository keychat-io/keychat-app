import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:keychat/app.dart';
import 'package:keychat_ecash/lnd/active_lnd_connection.dart';
import 'package:keychat_ecash/lnd/lnd_rest_client.dart';
import 'package:keychat_ecash/lnd/lnd_setting_page.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart';
import 'package:keychat_ecash/unified_wallet/pages/unified_transaction_page.dart';

/// LND Lightning wallet implementation for the unified wallet system.
class LndWallet extends WalletBase {
  LndWallet({required this.connection});

  final ActiveLndConnection connection;

  @override
  String get id => connection.identifier;

  @override
  String get displayName =>
      connection.info.name ?? connection.nodeInfo?.alias ?? _defaultName;

  @override
  WalletProtocol get protocol => WalletProtocol.lnd;

  @override
  int get balanceSats => connection.balance?.spendableBalanceSat ?? 0;

  @override
  bool get isBalanceLoading => connection.balance == null;

  @override
  IconData get icon => CupertinoIcons.bolt;

  @override
  Color get primaryColor => KeychatGlobal.bitcoinColor;

  @override
  String get subtitle => '${connection.info.host}:${connection.info.port}';

  @override
  bool get canSend => balanceSats > 0;

  @override
  bool get canReceive => true;

  @override
  bool get supportsLightning => true;

  @override
  ActiveLndConnection get rawData => connection;

  @override
  Widget settingsPage() => LndSettingPage(connection: connection);

  /// Node public key
  String? get nodePubkey => connection.nodeInfo?.identityPubkey;

  /// Node alias
  String? get nodeAlias => connection.nodeInfo?.alias;

  /// Number of active channels
  int get activeChannels => connection.nodeInfo?.numActiveChannels ?? 0;

  /// Default name for wallets without alias
  String get _defaultName => 'LND ${connection.info.host}';
}

/// LND transaction wrapper for unified transaction display.
///
/// Can represent either a payment (outgoing) or invoice (incoming).
class LndWalletTransaction extends WalletTransactionBase {
  LndWalletTransaction.fromPayment({
    required LndPayment payment,
    this.walletId,
  })  : _payment = payment,
        _invoice = null;

  LndWalletTransaction.fromInvoice({
    required LndInvoice invoice,
    this.walletId,
  })  : _invoice = invoice,
        _payment = null;

  final LndPayment? _payment;
  final LndInvoice? _invoice;

  @override
  final String? walletId;

  @override
  String get id => _payment?.paymentHash ?? _invoice?.rHash ?? '';

  @override
  int get amountSats {
    if (_payment != null) {
      return -_payment.valueSat; // Outgoing is negative
    }
    if (_invoice != null) {
      return _invoice.amtPaidSat ?? _invoice.valueSat;
    }
    return 0;
  }

  @override
  DateTime get timestamp {
    if (_payment != null) {
      return _payment.creationDateTime;
    }
    if (_invoice != null) {
      if (_invoice.settleDate != null && _invoice.settleDate! > 0) {
        return DateTime.fromMillisecondsSinceEpoch(_invoice.settleDate! * 1000);
      }
      return _invoice.creationDateTime;
    }
    return DateTime.now();
  }

  @override
  String? get description => _invoice?.memo;

  @override
  WalletTransactionStatus get status {
    if (_payment != null) {
      return switch (_payment.status) {
        LndPaymentStatus.succeeded => WalletTransactionStatus.success,
        LndPaymentStatus.failed => WalletTransactionStatus.failed,
        LndPaymentStatus.inFlight => WalletTransactionStatus.pending,
        LndPaymentStatus.unknown => WalletTransactionStatus.pending,
      };
    }
    if (_invoice != null) {
      if (_invoice.settled) {
        return WalletTransactionStatus.success;
      }
      if (_invoice.isExpired) {
        return WalletTransactionStatus.expired;
      }
      return WalletTransactionStatus.pending;
    }
    return WalletTransactionStatus.pending;
  }

  @override
  bool get isIncoming => _invoice != null;

  @override
  WalletProtocol get protocol => WalletProtocol.lnd;

  @override
  dynamic get rawData => _payment ?? _invoice;

  @override
  String? get preimage {
    if (_payment != null) {
      return _payment.paymentPreimage;
    }
    if (_invoice != null) {
      return _invoice.rPreimage;
    }
    return null;
  }

  @override
  String get paymentHash => _payment?.paymentHash ?? _invoice?.rHash ?? '';

  @override
  int? get fee => _payment?.feeSat;

  @override
  bool get isSuccess => status == WalletTransactionStatus.success;

  @override
  String? get invoice => _invoice?.paymentRequest ?? _payment?.paymentRequest;

  @override
  void navigateToTransactionDetail({String? walletId}) {
    Get.to<void>(
      () => UnifiedTransactionPage(
        lndTransaction: this,
        walletId: walletId,
      ),
      id: GetPlatform.isDesktop ? GetXNestKey.ecash : null,
    );
  }
}
