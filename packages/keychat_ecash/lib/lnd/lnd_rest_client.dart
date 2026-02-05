import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:keychat_ecash/lnd/lnd_connection_info.dart';

/// HTTP client for LND REST API with macaroon-based authentication.
///
/// Uses Dio for HTTP requests with support for self-signed certificates.
class LndRestClient {
  LndRestClient(this.connectionInfo) {
    _dio = Dio(
      BaseOptions(
        baseUrl: connectionInfo.baseUrl,
        headers: {
          'Grpc-Metadata-macaroon': connectionInfo.macaroon,
          'Content-Type': 'application/json',
        },
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    // Configure to accept self-signed certificates
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
  }

  final LndConnectionInfo connectionInfo;
  late final Dio _dio;

  /// Get basic node information.
  ///
  /// Returns node pubkey, alias, version, network, etc.
  Future<LndGetInfoResponse> getInfo() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/getinfo');
    return LndGetInfoResponse.fromJson(response.data!);
  }

  /// Get channel balance (spendable Lightning balance).
  Future<LndChannelBalance> getChannelBalance() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/v1/balance/channels');
    return LndChannelBalance.fromJson(response.data!);
  }

  /// List outgoing payments.
  ///
  /// [includeIncomplete] - Include pending payments.
  /// [maxPayments] - Maximum number of payments to return.
  /// [indexOffset] - Starting index for pagination.
  Future<LndListPaymentsResponse> listPayments({
    bool includeIncomplete = true,
    int? maxPayments,
    int? indexOffset,
  }) async {
    final queryParams = <String, dynamic>{
      'include_incomplete': includeIncomplete,
    };
    if (maxPayments != null) queryParams['max_payments'] = maxPayments;
    if (indexOffset != null) queryParams['index_offset'] = indexOffset;

    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/payments',
      queryParameters: queryParams,
    );
    return LndListPaymentsResponse.fromJson(response.data!);
  }

  /// List incoming invoices.
  ///
  /// [pendingOnly] - Only return unpaid invoices.
  /// [numMaxInvoices] - Maximum number of invoices to return.
  /// [indexOffset] - Starting index for pagination.
  Future<LndListInvoicesResponse> listInvoices({
    bool pendingOnly = false,
    int? numMaxInvoices,
    int? indexOffset,
  }) async {
    final queryParams = <String, dynamic>{
      'pending_only': pendingOnly,
    };
    if (numMaxInvoices != null) queryParams['num_max_invoices'] = numMaxInvoices;
    if (indexOffset != null) queryParams['index_offset'] = indexOffset;

    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/invoices',
      queryParameters: queryParams,
    );
    return LndListInvoicesResponse.fromJson(response.data!);
  }

  /// Pay a Lightning invoice.
  ///
  /// [invoice] - The BOLT11 payment request string.
  /// [timeout] - Payment timeout in seconds (default 60).
  /// [feeLimitSat] - Maximum fee willing to pay in sats.
  Future<LndSendPaymentResponse> payInvoice(
    String invoice, {
    int timeout = 60,
    int? feeLimitSat,
  }) async {
    final body = <String, dynamic>{
      'payment_request': invoice,
      'timeout_seconds': timeout,
    };
    if (feeLimitSat != null) {
      body['fee_limit'] = {'fixed': feeLimitSat.toString()};
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/channels/transactions',
      data: body,
    );
    return LndSendPaymentResponse.fromJson(response.data!);
  }

  /// Create a new Lightning invoice.
  ///
  /// [amountSats] - Invoice amount in satoshis.
  /// [memo] - Optional invoice description.
  /// [expiry] - Invoice expiry time in seconds (default 3600).
  Future<LndAddInvoiceResponse> addInvoice(
    int amountSats, {
    String? memo,
    int expiry = 3600,
  }) async {
    final body = <String, dynamic>{
      'value': amountSats.toString(),
      'expiry': expiry.toString(),
    };
    if (memo != null && memo.isNotEmpty) {
      body['memo'] = memo;
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/invoices',
      data: body,
    );
    return LndAddInvoiceResponse.fromJson(response.data!);
  }

  /// Decode a BOLT11 payment request.
  Future<LndPayReqResponse> decodePayReq(String payReq) async {
    final encoded = Uri.encodeComponent(payReq);
    final response =
        await _dio.get<Map<String, dynamic>>('/v1/payreq/$encoded');
    return LndPayReqResponse.fromJson(response.data!);
  }

  /// Lookup an invoice by payment hash.
  Future<LndInvoice> lookupInvoice(String rHashStr) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/v1/invoice/$rHashStr');
    return LndInvoice.fromJson(response.data!);
  }

  /// Close the HTTP client.
  void close() {
    _dio.close();
  }
}

/// Response from /v1/getinfo endpoint.
class LndGetInfoResponse {
  LndGetInfoResponse({
    required this.identityPubkey,
    required this.alias,
    required this.numActiveChannels,
    required this.numPeers,
    required this.blockHeight,
    required this.syncedToChain,
    required this.syncedToGraph,
    this.version,
    this.chains,
  });

  factory LndGetInfoResponse.fromJson(Map<String, dynamic> json) {
    return LndGetInfoResponse(
      identityPubkey: json['identity_pubkey'] as String? ?? '',
      alias: json['alias'] as String? ?? '',
      numActiveChannels: int.tryParse(
            json['num_active_channels']?.toString() ?? '0',
          ) ??
          0,
      numPeers: int.tryParse(json['num_peers']?.toString() ?? '0') ?? 0,
      blockHeight:
          int.tryParse(json['block_height']?.toString() ?? '0') ?? 0,
      syncedToChain: json['synced_to_chain'] as bool? ?? false,
      syncedToGraph: json['synced_to_graph'] as bool? ?? false,
      version: json['version'] as String?,
      chains: (json['chains'] as List<dynamic>?)
          ?.map((e) => LndChain.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String identityPubkey;
  final String alias;
  final int numActiveChannels;
  final int numPeers;
  final int blockHeight;
  final bool syncedToChain;
  final bool syncedToGraph;
  final String? version;
  final List<LndChain>? chains;

  String get network => chains?.firstOrNull?.network ?? 'mainnet';
}

/// Chain info from getinfo response.
class LndChain {
  LndChain({required this.chain, required this.network});

  factory LndChain.fromJson(Map<String, dynamic> json) {
    return LndChain(
      chain: json['chain'] as String? ?? 'bitcoin',
      network: json['network'] as String? ?? 'mainnet',
    );
  }

  final String chain;
  final String network;
}

/// Response from /v1/balance/channels endpoint.
class LndChannelBalance {
  LndChannelBalance({
    required this.localBalanceSat,
    required this.remoteBalanceSat,
    required this.pendingOpenLocalBalanceSat,
    required this.pendingOpenRemoteBalanceSat,
  });

  factory LndChannelBalance.fromJson(Map<String, dynamic> json) {
    // Handle nested amount structures
    int parseAmount(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is Map) {
        return int.tryParse(value['sat']?.toString() ?? '0') ?? 0;
      }
      return 0;
    }

    return LndChannelBalance(
      localBalanceSat: parseAmount(json['local_balance']),
      remoteBalanceSat: parseAmount(json['remote_balance']),
      pendingOpenLocalBalanceSat: parseAmount(json['pending_open_local_balance']),
      pendingOpenRemoteBalanceSat:
          parseAmount(json['pending_open_remote_balance']),
    );
  }

  final int localBalanceSat;
  final int remoteBalanceSat;
  final int pendingOpenLocalBalanceSat;
  final int pendingOpenRemoteBalanceSat;

  /// Spendable balance (local balance in channels)
  int get spendableBalanceSat => localBalanceSat;
}

/// Response from /v1/payments endpoint.
class LndListPaymentsResponse {
  LndListPaymentsResponse({
    required this.payments,
    this.firstIndexOffset,
    this.lastIndexOffset,
  });

  factory LndListPaymentsResponse.fromJson(Map<String, dynamic> json) {
    final paymentsList = json['payments'] as List<dynamic>? ?? [];
    return LndListPaymentsResponse(
      payments: paymentsList
          .map((e) => LndPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
      firstIndexOffset:
          int.tryParse(json['first_index_offset']?.toString() ?? ''),
      lastIndexOffset:
          int.tryParse(json['last_index_offset']?.toString() ?? ''),
    );
  }

  final List<LndPayment> payments;
  final int? firstIndexOffset;
  final int? lastIndexOffset;
}

/// A payment from listPayments.
class LndPayment {
  LndPayment({
    required this.paymentHash,
    required this.valueSat,
    required this.creationDate,
    required this.status,
    this.feeSat,
    this.paymentPreimage,
    this.paymentRequest,
    this.failureReason,
  });

  factory LndPayment.fromJson(Map<String, dynamic> json) {
    return LndPayment(
      paymentHash: json['payment_hash'] as String? ?? '',
      valueSat: int.tryParse(json['value_sat']?.toString() ?? '0') ?? 0,
      creationDate:
          int.tryParse(json['creation_date']?.toString() ?? '0') ?? 0,
      status: LndPaymentStatus.fromString(json['status'] as String? ?? ''),
      feeSat: int.tryParse(json['fee_sat']?.toString() ?? ''),
      paymentPreimage: json['payment_preimage'] as String?,
      paymentRequest: json['payment_request'] as String?,
      failureReason: json['failure_reason'] as String?,
    );
  }

  final String paymentHash;
  final int valueSat;
  final int creationDate;
  final LndPaymentStatus status;
  final int? feeSat;
  final String? paymentPreimage;
  final String? paymentRequest;
  final String? failureReason;

  DateTime get creationDateTime =>
      DateTime.fromMillisecondsSinceEpoch(creationDate * 1000);
}

/// Payment status enum.
enum LndPaymentStatus {
  unknown,
  inFlight,
  succeeded,
  failed;

  static LndPaymentStatus fromString(String status) {
    return switch (status.toUpperCase()) {
      'IN_FLIGHT' => LndPaymentStatus.inFlight,
      'SUCCEEDED' => LndPaymentStatus.succeeded,
      'FAILED' => LndPaymentStatus.failed,
      _ => LndPaymentStatus.unknown,
    };
  }
}

/// Response from /v1/invoices endpoint.
class LndListInvoicesResponse {
  LndListInvoicesResponse({
    required this.invoices,
    this.firstIndexOffset,
    this.lastIndexOffset,
  });

  factory LndListInvoicesResponse.fromJson(Map<String, dynamic> json) {
    final invoicesList = json['invoices'] as List<dynamic>? ?? [];
    return LndListInvoicesResponse(
      invoices: invoicesList
          .map((e) => LndInvoice.fromJson(e as Map<String, dynamic>))
          .toList(),
      firstIndexOffset:
          int.tryParse(json['first_index_offset']?.toString() ?? ''),
      lastIndexOffset:
          int.tryParse(json['last_index_offset']?.toString() ?? ''),
    );
  }

  final List<LndInvoice> invoices;
  final int? firstIndexOffset;
  final int? lastIndexOffset;
}

/// An invoice from listInvoices.
class LndInvoice {
  LndInvoice({
    required this.rHash,
    required this.paymentRequest,
    required this.valueSat,
    required this.creationDate,
    required this.expiry,
    required this.settled,
    this.rPreimage,
    this.memo,
    this.amtPaidSat,
    this.settleDate,
    this.state,
  });

  factory LndInvoice.fromJson(Map<String, dynamic> json) {
    return LndInvoice(
      rHash: json['r_hash'] as String? ?? '',
      paymentRequest: json['payment_request'] as String? ?? '',
      valueSat: int.tryParse(json['value']?.toString() ?? '0') ?? 0,
      creationDate:
          int.tryParse(json['creation_date']?.toString() ?? '0') ?? 0,
      expiry: int.tryParse(json['expiry']?.toString() ?? '3600') ?? 3600,
      settled: json['settled'] as bool? ?? false,
      rPreimage: json['r_preimage'] as String?,
      memo: json['memo'] as String?,
      amtPaidSat: int.tryParse(json['amt_paid_sat']?.toString() ?? ''),
      settleDate: int.tryParse(json['settle_date']?.toString() ?? ''),
      state: LndInvoiceState.fromString(json['state'] as String? ?? ''),
    );
  }

  final String rHash;
  final String paymentRequest;
  final int valueSat;
  final int creationDate;
  final int expiry;
  final bool settled;
  final String? rPreimage;
  final String? memo;
  final int? amtPaidSat;
  final int? settleDate;
  final LndInvoiceState? state;

  DateTime get creationDateTime =>
      DateTime.fromMillisecondsSinceEpoch(creationDate * 1000);

  DateTime get expiryDateTime => creationDateTime.add(Duration(seconds: expiry));

  bool get isExpired =>
      !settled && DateTime.now().isAfter(expiryDateTime);
}

/// Invoice state enum.
enum LndInvoiceState {
  open,
  settled,
  canceled,
  accepted;

  static LndInvoiceState fromString(String state) {
    return switch (state.toUpperCase()) {
      'OPEN' => LndInvoiceState.open,
      'SETTLED' => LndInvoiceState.settled,
      'CANCELED' => LndInvoiceState.canceled,
      'ACCEPTED' => LndInvoiceState.accepted,
      _ => LndInvoiceState.open,
    };
  }
}

/// Response from sendPayment (pay invoice).
class LndSendPaymentResponse {
  LndSendPaymentResponse({
    required this.paymentHash,
    this.paymentPreimage,
    this.paymentError,
    this.paymentRoute,
  });

  factory LndSendPaymentResponse.fromJson(Map<String, dynamic> json) {
    return LndSendPaymentResponse(
      paymentHash: json['payment_hash'] as String? ?? '',
      paymentPreimage: json['payment_preimage'] as String?,
      paymentError: json['payment_error'] as String?,
      paymentRoute: json['payment_route'] != null
          ? LndPaymentRoute.fromJson(
              json['payment_route'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final String paymentHash;
  final String? paymentPreimage;
  final String? paymentError;
  final LndPaymentRoute? paymentRoute;

  bool get isSuccess =>
      paymentPreimage != null &&
      paymentPreimage!.isNotEmpty &&
      (paymentError == null || paymentError!.isEmpty);
}

/// Payment route from sendPayment response.
class LndPaymentRoute {
  LndPaymentRoute({
    required this.totalFeesSat,
    required this.totalAmtSat,
  });

  factory LndPaymentRoute.fromJson(Map<String, dynamic> json) {
    return LndPaymentRoute(
      totalFeesSat:
          int.tryParse(json['total_fees']?.toString() ?? '0') ?? 0,
      totalAmtSat: int.tryParse(json['total_amt']?.toString() ?? '0') ?? 0,
    );
  }

  final int totalFeesSat;
  final int totalAmtSat;
}

/// Response from addInvoice.
class LndAddInvoiceResponse {
  LndAddInvoiceResponse({
    required this.rHash,
    required this.paymentRequest,
    this.addIndex,
  });

  factory LndAddInvoiceResponse.fromJson(Map<String, dynamic> json) {
    return LndAddInvoiceResponse(
      rHash: json['r_hash'] as String? ?? '',
      paymentRequest: json['payment_request'] as String? ?? '',
      addIndex: int.tryParse(json['add_index']?.toString() ?? ''),
    );
  }

  final String rHash;
  final String paymentRequest;
  final int? addIndex;
}

/// Response from decodePayReq.
class LndPayReqResponse {
  LndPayReqResponse({
    required this.destination,
    required this.paymentHash,
    required this.numSatoshis,
    required this.timestamp,
    required this.expiry,
    this.description,
    this.descriptionHash,
  });

  factory LndPayReqResponse.fromJson(Map<String, dynamic> json) {
    return LndPayReqResponse(
      destination: json['destination'] as String? ?? '',
      paymentHash: json['payment_hash'] as String? ?? '',
      numSatoshis: int.tryParse(json['num_satoshis']?.toString() ?? '0') ?? 0,
      timestamp: int.tryParse(json['timestamp']?.toString() ?? '0') ?? 0,
      expiry: int.tryParse(json['expiry']?.toString() ?? '3600') ?? 3600,
      description: json['description'] as String?,
      descriptionHash: json['description_hash'] as String?,
    );
  }

  final String destination;
  final String paymentHash;
  final int numSatoshis;
  final int timestamp;
  final int expiry;
  final String? description;
  final String? descriptionHash;
}
