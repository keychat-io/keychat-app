import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:ndk/ndk.dart' show TransactionResult;

/// A sealed class representing the result of a lightning payment.
/// Can be either a Cashu transaction or an NWC transaction result.
sealed class PaymentResult {
  const PaymentResult();

  /// Returns the preimage of the payment if available
  String? get preimage;

  /// Returns the fee paid for the payment in sats if available
  int? get fee;

  /// Returns whether the payment was successful
  bool get isSuccess;
}

/// Payment result from Cashu mint
final class CashuPaymentResult extends PaymentResult {
  const CashuPaymentResult(this.transaction);

  final Transaction transaction;

  @override
  String? get preimage => transaction.token;

  @override
  int? get fee => transaction.fee.toInt();

  @override
  bool get isSuccess => transaction.status == TransactionStatus.success;

  /// Get the underlying transaction
  Transaction get tx => transaction;
}

/// Payment result from NWC (Nostr Wallet Connect)
final class NwcPaymentResult extends PaymentResult {
  const NwcPaymentResult(this.transactionResult);

  final TransactionResult transactionResult;

  @override
  String? get preimage => transactionResult.preimage;

  @override
  int? get fee => transactionResult.feesPaid != null
      ? transactionResult.feesPaid! ~/ 1000
      : null;

  @override
  bool get isSuccess => true; // NWC payment is always success if returned

  /// Get the underlying transaction result
  TransactionResult get tx => transactionResult;
}
