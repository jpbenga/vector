import 'dart:async';

import 'package:http/http.dart' as http;

import '../domain/generator_context.dart';

typedef GeneratorInvoke =
    Future<Map<String, dynamic>> Function(Map<String, Object?> body);

/// A lost chat response is resolved through owner-scoped reads of its turn.
/// Never resend a chat, transcription, or user action automatically.
class GeneratorRequestRecovery {
  GeneratorRequestRecovery({
    required this.invoke,
    DateTime Function()? clock,
    Future<void> Function(Duration)? wait,
  }) : clock = clock ?? DateTime.now,
       wait = wait ?? Future<void>.delayed;

  final GeneratorInvoke invoke;
  final DateTime Function() clock;
  final Future<void> Function(Duration) wait;

  static const connectionMessage =
      'La connexion au service a été interrompue. Votre demande reste affichée ; son résultat n’a pas pu être récupéré.';
  static const timeoutMessage =
      'La préparation a pris trop de temps. Votre conversation est conservée ; rechargez-la avant de réessayer.';

  Future<Map<String, dynamic>> request(Map<String, Object?> body) async {
    try {
      return await invoke(body);
    } on http.ClientException {
      if (_canRecover(body)) return _recover(body);
      throw StateError(connectionMessage);
    } on TimeoutException {
      if (_canRecover(body)) return _recover(body);
      throw StateError(timeoutMessage);
    }
  }

  bool _canRecover(Map<String, Object?> body) =>
      body['action'] == 'chat' &&
      body['requestId'] is String &&
      body['conversationId'] is String;

  Future<Map<String, dynamic>> _recover(Map<String, Object?> body) async {
    final deadline = clock().add(const Duration(minutes: 2));
    const delays = [0, 2, 4, 6, 8, 10, 15, 20, 20, 20];
    for (final seconds in delays) {
      final remaining = deadline.difference(clock());
      if (remaining <= Duration.zero) break;
      final delay = Duration(seconds: seconds);
      if (delay >= remaining) break;
      if (seconds > 0) await wait(delay);
      final callBudget = deadline.difference(clock());
      if (callBudget <= Duration.zero) break;
      Map<String, dynamic> result;
      try {
        result =
            await invoke({
              'action': 'status',
              'conversationId': body['conversationId'],
              'requestId': body['requestId'],
              'revision': body['revision'] ?? 0,
              'includeResult': true,
            }).timeout(
              callBudget < const Duration(seconds: 8)
                  ? callBudget
                  : const Duration(seconds: 8),
            );
      } on http.ClientException {
        continue;
      } on TimeoutException {
        continue;
      }
      final turn = generatorMap(result['turn']);
      switch (turn['status']) {
        case 'complete':
          if (result['state'] is Map) return {'state': result['state']};
          // An older backend cannot provide this exact turn's result. Do not
          // substitute a newer conversation revision or replay a paid chat.
          throw StateError(
            'Votre réponse est enregistrée. Actualisez la conversation pour la retrouver.',
          );
        case 'failed':
          throw StateError(
            turn['error']?.toString() ??
                'Cette préparation s’est arrêtée côté serveur. Votre conversation est conservée.',
          );
        case 'cancelled':
          throw StateError('La préparation a été interrompue.');
      }
    }
    throw StateError(connectionMessage);
  }
}
