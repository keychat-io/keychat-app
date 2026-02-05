/// NWC (Nostr Wallet Connect) protocol models.
///
/// Contains event kinds, methods, and response models for NIP-47.
library;

/// NWC event kinds as defined in NIP-47.
class NwcEventKinds {
  NwcEventKinds._();

  /// Kind for NWC info event (wallet capabilities).
  static const int info = 13194;

  /// Kind for NWC request events (client -> wallet).
  static const int request = 23194;

  /// Kind for NWC response events (wallet -> client).
  static const int response = 23195;

  /// Kind for NWC notification events.
  static const int notification = 23196;
}

/// NWC methods as defined in NIP-47.
enum NwcMethod {
  getBalance('get_balance'),
  getInfo('get_info'),
  payInvoice('pay_invoice'),
  makeInvoice('make_invoice'),
  lookupInvoice('lookup_invoice'),
  listTransactions('list_transactions'),
  multiPayInvoice('multi_pay_invoice'),
  payKeysend('pay_keysend'),
  multiPayKeysend('multi_pay_keysend');

  const NwcMethod(this.value);

  /// The method name string value.
  final String value;

  /// Parses a method string to enum value.
  static NwcMethod? fromString(String value) {
    for (final method in NwcMethod.values) {
      if (method.value == value) return method;
    }
    return null;
  }
}

/// Base class for NWC requests.
class NwcRequest {
  /// Creates a new NwcRequest.
  const NwcRequest({
    required this.method,
    this.params = const {},
  });

  /// The method name.
  final String method;

  /// The request parameters.
  final Map<String, dynamic> params;

  /// Converts to JSON map.
  Map<String, dynamic> toJson() => {
        'method': method,
        'params': params,
      };
}

/// Base class for NWC responses.
class NwcResponse {
  /// Creates a new NwcResponse.
  const NwcResponse({
    required this.resultType,
    this.result,
    this.error,
  });

  /// The result type (method name).
  final String resultType;

  /// The result data (if success).
  final Map<String, dynamic>? result;

  /// The error data (if failed).
  final NwcError? error;

  /// Whether this response is an error.
  bool get isError => error != null;

  /// Factory to create from JSON.
  factory NwcResponse.fromJson(Map<String, dynamic> json) {
    NwcError? error;
    if (json['error'] != null) {
      error = NwcError.fromJson(json['error'] as Map<String, dynamic>);
    }
    return NwcResponse(
      resultType: json['result_type'] as String,
      result: json['result'] as Map<String, dynamic>?,
      error: error,
    );
  }
}

/// NWC error response.
class NwcError {
  /// Creates a new NwcError.
  const NwcError({
    required this.code,
    this.message,
  });

  /// The error code.
  final String code;

  /// The error message.
  final String? message;

  /// Factory to create from JSON.
  factory NwcError.fromJson(Map<String, dynamic> json) {
    return NwcError(
      code: json['code'] as String,
      message: json['message'] as String?,
    );
  }

  @override
  String toString() => 'NwcError($code: $message)';
}

/// Response for get_balance method.
class GetBalanceResponse {
  /// Creates a new GetBalanceResponse.
  const GetBalanceResponse({
    required this.balanceMsats,
    this.maxAmount,
    this.budgetRenewal,
  });

  /// Balance in millisats.
  final int balanceMsats;

  /// Max amount for single payment.
  final int? maxAmount;

  /// Budget renewal info.
  final String? budgetRenewal;

  /// Balance in sats.
  int get balanceSats => balanceMsats ~/ 1000;

  /// Factory to create from JSON.
  factory GetBalanceResponse.fromJson(Map<String, dynamic> json) {
    return GetBalanceResponse(
      balanceMsats: json['balance'] as int,
      maxAmount: json['max_amount'] as int?,
      budgetRenewal: json['budget_renewal'] as String?,
    );
  }
}

/// Response for get_info method.
class GetInfoResponse {
  /// Creates a new GetInfoResponse.
  const GetInfoResponse({
    this.alias,
    this.color,
    this.pubkey,
    this.network,
    this.blockHeight,
    this.blockHash,
    this.methods = const [],
    this.notifications = const [],
  });

  /// Node alias.
  final String? alias;

  /// Node color.
  final String? color;

  /// Node pubkey.
  final String? pubkey;

  /// Network (mainnet, testnet, etc.).
  final String? network;

  /// Current block height.
  final int? blockHeight;

  /// Current block hash.
  final String? blockHash;

  /// Supported methods.
  final List<String> methods;

  /// Supported notifications.
  final List<String> notifications;

  /// Factory to create from JSON.
  factory GetInfoResponse.fromJson(Map<String, dynamic> json) {
    return GetInfoResponse(
      alias: json['alias'] as String?,
      color: json['color'] as String?,
      pubkey: json['pubkey'] as String?,
      network: json['network'] as String?,
      blockHeight: json['block_height'] as int?,
      blockHash: json['block_hash'] as String?,
      methods: (json['methods'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      notifications: (json['notifications'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// Response for list_transactions method.
class ListTransactionsResponse {
  /// Creates a new ListTransactionsResponse.
  const ListTransactionsResponse({
    required this.transactions,
  });

  /// List of transactions.
  final List<TransactionResult> transactions;

  /// Factory to create from JSON.
  factory ListTransactionsResponse.fromJson(Map<String, dynamic> json) {
    final txList = json['transactions'] as List<dynamic>?;
    return ListTransactionsResponse(
      transactions: txList
              ?.map((tx) =>
                  TransactionResult.fromJson(tx as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Transaction result model.
///
/// Compatible with existing NwcWalletTransaction usage.
class TransactionResult {
  /// Creates a new TransactionResult.
  const TransactionResult({
    required this.type,
    required this.paymentHash,
    required this.amount,
    required this.createdAt,
    this.invoice,
    this.description,
    this.descriptionHash,
    this.preimage,
    this.feesPaid,
    this.settledAt,
    this.expiresAt,
    this.metadata,
    this.state,
  });

  /// Transaction type (incoming/outgoing).
  final String type;

  /// Invoice string.
  final String? invoice;

  /// Description.
  final String? description;

  /// Description hash.
  final String? descriptionHash;

  /// Preimage (proof of payment).
  final String? preimage;

  /// Payment hash.
  final String paymentHash;

  /// Amount in millisats.
  final int amount;

  /// Fees paid in millisats.
  final int? feesPaid;

  /// Created timestamp (Unix seconds).
  final int createdAt;

  /// Settled timestamp (Unix seconds).
  final int? settledAt;

  /// Expiry timestamp (Unix seconds).
  final int? expiresAt;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  /// Transaction state.
  final String? state;

  /// Factory to create from JSON.
  factory TransactionResult.fromJson(Map<String, dynamic> json) {
    return TransactionResult(
      type: json['type'] as String,
      invoice: json['invoice'] as String?,
      description: json['description'] as String?,
      descriptionHash: json['description_hash'] as String?,
      preimage: json['preimage'] as String?,
      paymentHash: json['payment_hash'] as String,
      amount: json['amount'] as int,
      feesPaid: json['fees_paid'] as int?,
      createdAt: json['created_at'] as int,
      settledAt: json['settled_at'] as int?,
      expiresAt: json['expires_at'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      state: json['state'] as String?,
    );
  }

  /// Amount in sats (convenience getter).
  int get amountSat => amount ~/ 1000;

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
        'type': type,
        'invoice': invoice,
        'description': description,
        'description_hash': descriptionHash,
        'preimage': preimage,
        'payment_hash': paymentHash,
        'amount': amount,
        'fees_paid': feesPaid,
        'created_at': createdAt,
        'settled_at': settledAt,
        'expires_at': expiresAt,
        'metadata': metadata,
        'state': state,
      };
}

/// Response for pay_invoice method.
class PayInvoiceResponse {
  /// Creates a new PayInvoiceResponse.
  const PayInvoiceResponse({
    required this.preimage,
    this.feesPaid,
  });

  /// Payment preimage (proof of payment).
  final String preimage;

  /// Fees paid in millisats.
  final int? feesPaid;

  /// Factory to create from JSON.
  factory PayInvoiceResponse.fromJson(Map<String, dynamic> json) {
    return PayInvoiceResponse(
      preimage: json['preimage'] as String,
      feesPaid: json['fees_paid'] as int?,
    );
  }
}

/// Response for make_invoice method.
class MakeInvoiceResponse {
  /// Creates a new MakeInvoiceResponse.
  const MakeInvoiceResponse({
    required this.invoice,
    required this.paymentHash,
    this.amountSat,
    this.description,
    this.createdAt,
    this.expiresAt,
    this.feesPaid,
    this.preimage,
  });

  /// The generated invoice (bolt11).
  final String invoice;

  /// The payment hash.
  final String paymentHash;

  /// Amount in sats.
  final int? amountSat;

  /// Description.
  final String? description;

  /// Created timestamp.
  final int? createdAt;

  /// Expiry timestamp.
  final int? expiresAt;

  /// Fees paid.
  final int? feesPaid;

  /// Preimage.
  final String? preimage;

  /// Factory to create from JSON.
  factory MakeInvoiceResponse.fromJson(Map<String, dynamic> json) {
    return MakeInvoiceResponse(
      invoice: json['invoice'] as String,
      paymentHash: json['payment_hash'] as String,
      amountSat: json['amount'] as int?,
      description: json['description'] as String?,
      createdAt: json['created_at'] as int?,
      expiresAt: json['expires_at'] as int?,
      feesPaid: json['fees_paid'] as int?,
      preimage: json['preimage'] as String?,
    );
  }
}

/// Response for lookup_invoice method.
class LookupInvoiceResponse {
  /// Creates a new LookupInvoiceResponse.
  const LookupInvoiceResponse({
    required this.transaction,
  });

  /// The transaction details.
  final TransactionResult transaction;

  /// Factory to create from JSON.
  factory LookupInvoiceResponse.fromJson(Map<String, dynamic> json) {
    return LookupInvoiceResponse(
      transaction: TransactionResult.fromJson(json),
    );
  }
}

/// Transaction type enum.
class TransactionType {
  TransactionType._();

  /// Incoming payment.
  static const String incoming = 'incoming';

  /// Outgoing payment.
  static const String outgoing = 'outgoing';
}
