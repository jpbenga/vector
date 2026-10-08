import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/generator_context.dart';

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
    try {
      final response = await client.functions
          .invoke(
            const String.fromEnvironment(
              'LECTOR_GENERATOR_ENDPOINT',
              defaultValue: 'lector-generator',
            ),
            body: body,
          )
          .timeout(const Duration(seconds: 120));
      final data = generatorMap(response.data);
      if (data['error'] != null) throw StateError(data['error'].toString());
      return data;
    } on TimeoutException {
      throw StateError(
        'La préparation a pris trop de temps. Votre conversation est conservée ; rechargez-la avant de réessayer.',
      );
    } on FunctionException catch (error) {
      final message = generatorMap(error.details)['error'];
      throw StateError(
        message?.toString() ??
            'L’assistant IA n’est pas encore disponible. Sa configuration serveur doit être activée.',
      );
    }
  }
}
