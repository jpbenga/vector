import 'dart:async';

import 'package:copilot/features/generator/data/generator_request_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const chat = <String, Object?>{
  'action': 'chat',
  'requestId': 'the-original-request',
  'conversationId': 'the-original-conversation',
  'revision': 3,
  'message': 'Deux tickets pour dimanche, avec six et trois rencontres.',
};

void main() {
  test(
    'a lost response recovers the exact turn without another paid chat',
    () async {
      final calls = <Map<String, Object?>>[];
      final state = <String, Object?>{
        'id': chat['conversationId'],
        'revision': 4,
        'tickets': [
          {'picks': List<Object>.filled(6, 'selection'), 'stake': 25},
          {'picks': List<Object>.filled(3, 'selection'), 'stake': 50},
        ],
      };
      final request = GeneratorRequestRecovery(
        invoke: (body) async {
          calls.add(body);
          if (body['action'] == 'chat') {
            throw http.ClientException('Load failed');
          }
          return calls.length == 2
              ? {
                  'turn': {'status': 'pending'},
                }
              : {
                  'turn': {'status': 'complete'},
                  'state': state,
                };
        },
        wait: (_) async {},
      );
      expect(await request.request(chat), {'state': state});
      expect(calls.map((body) => body['action']), ['chat', 'status', 'status']);
      for (final body in calls.skip(1)) {
        expect(body['requestId'], chat['requestId']);
        expect(body['conversationId'], chat['conversationId']);
        expect(body.containsKey('message'), isFalse);
        expect(body.containsKey('context'), isFalse);
      }
    },
  );

  test(
    'temporary losses during recovery do not resend the initial prompt',
    () async {
      var chats = 0, reads = 0;
      final request = GeneratorRequestRecovery(
        invoke: (body) async {
          if (body['action'] == 'chat') {
            chats++;
            throw http.ClientException('Load failed');
          }
          reads++;
          if (reads == 1) throw http.ClientException('Load failed');
          if (reads == 2) throw TimeoutException('status connection');
          return {
            'turn': {'status': 'complete'},
            'state': {'revision': 4},
          };
        },
        wait: (_) async {},
      );
      expect(await request.request(chat), {
        'state': {'revision': 4},
      });
      expect(chats, 1);
      expect(reads, 3);
    },
  );

  test(
    'server failure remains distinct from a lost browser response',
    () async {
      var calls = 0;
      final request = GeneratorRequestRecovery(
        invoke: (body) async {
          calls++;
          if (body['action'] == 'chat') {
            throw http.ClientException('Load failed');
          }
          return {
            'turn': {
              'status': 'failed',
              'error': 'La préparation de la réponse IA a dépassé le délai.',
            },
          };
        },
      );
      await expectLater(
        request.request(chat),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'La préparation de la réponse IA a dépassé le délai.',
          ),
        ),
      );
      expect(calls, 2);
    },
  );

  test(
    'an ongoing request stops recovery after ten reads and preserves its identity',
    () async {
      var now = DateTime.utc(2026, 10, 11);
      var chats = 0, reads = 0;
      final request = GeneratorRequestRecovery(
        clock: () => now,
        wait: (duration) async => now = now.add(duration),
        invoke: (body) async {
          if (body['action'] == 'chat') {
            chats++;
            throw http.ClientException(
              'Load failed',
              Uri.parse('https://private.test/function'),
            );
          }
          reads++;
          return {
            'turn': {'status': 'pending'},
          };
        },
      );
      await expectLater(
        request.request(chat),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            GeneratorRequestRecovery.connectionMessage,
          ),
        ),
      );
      expect(chats, 1);
      expect(reads, 10);
      expect(
        now.difference(DateTime.utc(2026, 10, 11)),
        lessThan(const Duration(minutes: 6)),
      );
    },
  );

  test(
    'an old status response cannot replace the result with a different revision',
    () async {
      final calls = <Object?>[];
      final request = GeneratorRequestRecovery(
        invoke: (body) async {
          calls.add(body['action']);
          if (body['action'] == 'chat') {
            throw http.ClientException('Load failed');
          }
          return {
            'turn': {'status': 'complete'},
          };
        },
      );
      await expectLater(request.request(chat), throwsStateError);
      expect(calls, ['chat', 'status']);
    },
  );

  test(
    'transcriptions and user actions are never automatically replayed',
    () async {
      for (final action in ['transcribe', 'apply', 'keep', 'decision_action']) {
        var calls = 0;
        final request = GeneratorRequestRecovery(
          invoke: (body) async {
            calls++;
            throw http.ClientException(
              'Load failed',
              Uri.parse('https://private.test/function'),
            );
          },
        );
        await expectLater(
          request.request({...chat, 'action': action}),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              GeneratorRequestRecovery.connectionMessage,
            ),
          ),
        );
        expect(calls, 1);
      }
    },
  );

  test('explicit HTTP errors do not enter connection recovery', () async {
    var calls = 0;
    final request = GeneratorRequestRecovery(
      invoke: (body) async {
        calls++;
        throw StateError('Votre connexion doit être renouvelée.');
      },
    );
    await expectLater(request.request(chat), throwsStateError);
    expect(calls, 1);
  });
}
