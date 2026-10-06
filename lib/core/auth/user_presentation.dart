import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String lectorInitialsForUser(User? user) {
  return lectorInitialsForName(
    lectorDisplayNameForUser(user) ?? user?.email ?? 'LS',
  );
}

String? lectorDisplayNameForUser(User? user) {
  final metadata = user?.userMetadata;
  for (final key in ['full_name', 'name', 'display_name']) {
    final value = metadata?[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String lectorInitialsForName(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+|@'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
  if (parts.isNotEmpty) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return 'LS';
}
