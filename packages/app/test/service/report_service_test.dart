import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/service/report.service.dart';

class FakeReportApiClient implements ReportApiClient {
  FakeReportApiClient({this.reasonsResponse, this.submitResponse});

  Object? reasonsResponse;
  Object? submitResponse;
  Object? submittedBody;

  @override
  Future<Object?> getReasons() async => reasonsResponse;

  @override
  Future<Object?> submitReport(Map<String, dynamic> body) async {
    submittedBody = body;
    return submitResponse;
  }
}

void main() {
  group('ReportReason', () {
    test('matches reasons by value for dropdown selection stability', () {
      const fallbackReason = ReportReason(
        value: 'spam_or_scam',
        label: 'Spam or scam',
      );
      final serverReason = ReportReason.fromJson(const {
        'value': 'spam_or_scam',
        'label': 'Spam or scam',
      });

      expect(serverReason, fallbackReason);
      expect([serverReason].where((reason) => reason == fallbackReason), [
        serverReason,
      ]);
    });
  });

  group('ReportService', () {
    test('uses server reasons when response is valid', () async {
      final service = ReportService(
        apiClient: FakeReportApiClient(
          reasonsResponse: {
            'code': 0,
            'data': {
              'reasons': [
                {'value': 'spam_or_scam', 'label': 'Spam or scam'},
                {'value': 'other', 'label': 'Other'},
              ],
            },
          },
        ),
      );

      final reasons = await service.getReasons();

      expect(reasons.map((r) => r.value), ['spam_or_scam', 'other']);
      expect(reasons.first.label, 'Spam or scam');
    });

    test('deduplicates server reasons by value for dropdown items', () async {
      final service = ReportService(
        apiClient: FakeReportApiClient(
          reasonsResponse: {
            'code': 0,
            'data': {
              'reasons': [
                {'value': 'spam_or_scam', 'label': 'Spam or scam'},
                {'value': 'spam_or_scam', 'label': 'Spam or scam duplicate'},
                {'value': 'other', 'label': 'Other'},
              ],
            },
          },
        ),
      );

      final reasons = await service.getReasons();

      expect(reasons.map((r) => r.value), ['spam_or_scam', 'other']);
      expect(reasons.first.label, 'Spam or scam');
    });

    test('falls back to local reasons when server request fails', () async {
      final service = ReportService(
        apiClient: FakeReportApiClient(reasonsResponse: Exception('offline')),
      );

      final reasons = await service.getReasons();

      expect(reasons.map((r) => r.value), contains('child_safety'));
      expect(reasons.last.value, 'other');
    });

    test('submits report and returns report id', () async {
      final client = FakeReportApiClient(
        submitResponse: {
          'code': 0,
          'data': {'reportId': 'rpt_123', 'status': 'pending'},
        },
      );
      final service = ReportService(apiClient: client);

      final result = await service.submitReport(
        ReportRequest(
          reportType: ReportType.message,
          reason: 'spam_or_scam',
          reporterPubkey: 'a' * 64,
          reportedPubkey: 'b' * 64,
          roomId: '1',
          messageId: '42',
          eventId: 'event-id',
          relayUrls: const ['wss://relay.example.com'],
          evidence: const {
            'selectedMessages': [
              {'messageId': '42', 'plaintext': 'phishing link'},
            ],
          },
          additionalContext: 'looks like a scam',
          clientMeta: const {'platform': 'ios'},
        ),
      );

      expect(result.reportId, 'rpt_123');
      expect(result.status, 'pending');
      expect(client.submittedBody, {
        'reportType': 'message',
        'reason': 'spam_or_scam',
        'reporterPubkey': 'a' * 64,
        'reportedPubkey': 'b' * 64,
        'roomId': '1',
        'messageId': '42',
        'eventId': 'event-id',
        'relayUrls': ['wss://relay.example.com'],
        'evidence': {
          'selectedMessages': [
            {'messageId': '42', 'plaintext': 'phishing link'},
          ],
        },
        'additionalContext': 'looks like a scam',
        'clientMeta': {'platform': 'ios'},
      });
    });
  });
}
