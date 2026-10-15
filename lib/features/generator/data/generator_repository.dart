import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/generator_context.dart';
import 'generator_request_recovery.dart';

abstract interface class GeneratorRepository {
  Future<Map<String, dynamic>> request(Map<String, Object?> body);
}

class SupabaseGeneratorRepository implements GeneratorRepository {
  SupabaseGeneratorRepository(this.client);
  final SupabaseClient client;
  @override
  Future<Map<String, dynamic>> request(Map<String, Object?> body) async {
    if (client.auth.currentUser == null) {
      throw StateError('Connectez-vous pour utiliser l’assistant.');
    }
    return GeneratorRequestRecovery(invoke: _invoke).request(body);
  }

  Future<Map<String, dynamic>> _invoke(Map<String, Object?> body) async {
    try {
      final response = await client.functions
          .invoke(
            const String.fromEnvironment(
              'LECTOR_GENERATOR_ENDPOINT',
              defaultValue: 'lector-generator',
            ),
            body: body,
            headers: {
              'x-lector-client-revision': const String.fromEnvironment(
                'LECTOR_RELEASE_REVISION',
                defaultValue: 'unversioned',
              ),
            },
          )
          .timeout(GeneratorRequestRecovery.requestTimeout);
      final data = generatorMap(response.data);
      if (data['error'] != null) throw StateError(data['error'].toString());
      return data;
    } on FunctionException catch (error) {
      final message = generatorMap(error.details)['error'];
      throw StateError(
        message?.toString() ?? 'L’assistant est temporairement indisponible.',
      );
    }
  }
}
