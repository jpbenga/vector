import 'package:flutter_test/flutter_test.dart';
import 'package:copilot/features/admin/domain/operations_issue.dart';

void main() {
  test(
    'screenshot messages map to distinct explanations before generic HTTP/quota rules',
    () {
      final cases = <String, String>{
        'FunctionException(status: 401, details: {error: Invalid user token.}, reasonPhrase: )':
            'admin_session',
        'Run marked failed after exceeding stale running window.':
            'missing_completion',
        'build-match-feed-snapshot failed with 422: {"ok":false,"error":"Refusing to publish an empty match feed snapshot."}':
            'empty_snapshot',
        'sync-match-results failed with 500: {"error":"Error: Missing api_football_sync_run_id for quota reservation"}':
            'missing_collection_id',
        'api-football-sync failed with 500: {"error":"Enrichment scope exceeds one sync run; split the request by league."}':
            'enrichment_too_large',
      };
      for (final entry in cases.entries) {
        expect(
          explainOperationsIssue(entry.key).code,
          entry.value,
          reason: entry.key,
        );
      }
    },
  );
  test('a provider 401 does not tell the user to log in again', () {
    expect(
      explainOperationsIssue('API-Football 401 for /fixtures').reconnect,
      isFalse,
    );
    expect(
      explainOperationsIssue(
        'FunctionException(status: 401)',
        adminRequest: true,
      ).reconnect,
      isTrue,
    );
  });
  test('quota conditions and unknown errors do not invent causes', () {
    expect(
      explainOperationsIssue('Quota API-Football : daily_limit').code,
      'daily_quota',
    );
    expect(
      explainOperationsIssue('Quota API-Football : minute_limit').code,
      'request_rate',
    );
    expect(
      explainOperationsIssue('500 unfamiliar failure').code,
      'server_error',
    );
    expect(explainOperationsIssue('unfamiliar failure').code, 'unknown');
    expect(explainOperationsIssue('').code, 'unknown');
  });
}
