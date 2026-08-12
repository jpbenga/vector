import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import 'supabase_initializer.dart';

class SupabaseUserScope {
  const SupabaseUserScope({required this.client, required this.userId});

  final SupabaseClient client;
  final String userId;

  static SupabaseUserScope? current() {
    if (!getIt.isRegistered<SupabaseInitializer>()) {
      return null;
    }

    final client = getIt<SupabaseInitializer>().client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null || userId.isEmpty) {
      return null;
    }

    return SupabaseUserScope(client: client, userId: userId);
  }
}
