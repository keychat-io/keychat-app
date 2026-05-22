import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:keychat/global.dart';

enum ReportType {
  message('message'),
  user('user'),
  group('group'),
  appFeedback('app_feedback');

  const ReportType(this.value);
  final String value;
}

@immutable
class ReportReason {
  const ReportReason({required this.value, required this.label});

  factory ReportReason.fromJson(Map<String, dynamic> json) {
    return ReportReason(
      value: json['value'] as String,
      label: json['label'] as String,
    );
  }

  final String value;
  final String label;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReportReason && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

class ReportRequest {
  const ReportRequest({
    required this.reportType,
    required this.reason,
    this.reporterPubkey,
    this.reportedPubkey,
    this.roomId,
    this.messageId,
    this.eventId,
    this.relayUrls = const [],
    this.evidence,
    this.additionalContext,
    this.clientMeta,
  });

  final ReportType reportType;
  final String reason;
  final String? reporterPubkey;
  final String? reportedPubkey;
  final String? roomId;
  final String? messageId;
  final String? eventId;
  final List<String> relayUrls;
  final Map<String, dynamic>? evidence;
  final String? additionalContext;
  final Map<String, dynamic>? clientMeta;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'reportType': reportType.value,
      'reason': reason,
    };
    void addString(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        json[key] = value.trim();
      }
    }

    addString('reporterPubkey', reporterPubkey);
    addString('reportedPubkey', reportedPubkey);
    addString('roomId', roomId);
    addString('messageId', messageId);
    addString('eventId', eventId);
    if (relayUrls.isNotEmpty) {
      json['relayUrls'] = relayUrls;
    }
    if (evidence != null && evidence!.isNotEmpty) {
      json['evidence'] = evidence;
    }
    addString('additionalContext', additionalContext);
    if (clientMeta != null && clientMeta!.isNotEmpty) {
      json['clientMeta'] = clientMeta;
    }
    return json;
  }
}

class ReportSubmitResult {
  const ReportSubmitResult({required this.reportId, required this.status});

  final String reportId;
  final String status;
}

abstract class ReportApiClient {
  Future<Object?> getReasons();
  Future<Object?> submitReport(Map<String, dynamic> body);
}

class DioReportApiClient implements ReportApiClient {
  DioReportApiClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<Object?> getReasons() async {
    final response = await _dio.get<Object?>(
      '${KeychatGlobal.notifycationServer}/reports/reasons',
    );
    return response.data;
  }

  @override
  Future<Object?> submitReport(Map<String, dynamic> body) async {
    final response = await _dio.post<Object?>(
      '${KeychatGlobal.notifycationServer}/reports',
      data: body,
    );
    return response.data;
  }
}

class ReportService {
  ReportService({ReportApiClient? apiClient})
    : _apiClient = apiClient ?? DioReportApiClient();

  ReportService._() : _apiClient = DioReportApiClient();

  static final ReportService instance = ReportService._();

  final ReportApiClient _apiClient;

  static const fallbackReasons = <ReportReason>[
    ReportReason(value: 'spam_or_scam', label: 'Spam or scam'),
    ReportReason(value: 'harassment_or_hate', label: 'Harassment or hate'),
    ReportReason(value: 'impersonation', label: 'Impersonation'),
    ReportReason(
      value: 'sexual_or_graphic_content',
      label: 'Sexual or graphic content',
    ),
    ReportReason(value: 'child_safety', label: 'Child safety concern'),
    ReportReason(value: 'illegal_activity', label: 'Illegal activity'),
    ReportReason(
      value: 'malware_or_harmful_link',
      label: 'Malware or harmful link',
    ),
    ReportReason(value: 'privacy_violation', label: 'Privacy violation'),
    ReportReason(value: 'other', label: 'Other'),
  ];

  Future<List<ReportReason>> getReasons() async {
    try {
      final response = await _apiClient.getReasons();
      final envelope = _asMap(response);
      final data = _asMap(envelope?['data']);
      final reasons = data?['reasons'];
      if (reasons is! List) return fallbackReasons;
      final parsed = reasons
          .map(_asMap)
          .nonNulls
          .map(ReportReason.fromJson)
          .toList();
      final uniqueReasons = _uniqueByValue(parsed);
      return uniqueReasons.isEmpty ? fallbackReasons : uniqueReasons;
    } catch (_) {
      return fallbackReasons;
    }
  }

  Future<ReportSubmitResult> submitReport(ReportRequest request) async {
    final response = await _apiClient.submitReport(request.toJson());
    final envelope = _asMap(response);
    if (envelope == null || envelope['code'] != 0) {
      throw Exception(envelope?['msg'] ?? 'Failed to submit report');
    }
    final data = _asMap(envelope['data']);
    final reportId = data?['reportId'];
    final status = data?['status'];
    if (reportId is! String || status is! String) {
      throw Exception('Invalid report response');
    }
    return ReportSubmitResult(reportId: reportId, status: status);
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  List<ReportReason> _uniqueByValue(List<ReportReason> reasons) {
    final seen = <String>{};
    return [
      for (final reason in reasons)
        if (seen.add(reason.value)) reason,
    ];
  }
}
