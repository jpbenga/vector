// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

void cleanOAuthRedirectUrl() {
  final uri = Uri.base;
  if (!uri.queryParameters.containsKey('code')) {
    return;
  }

  final cleanUri = uri.replace(queryParameters: const {}, fragment: '');
  html.window.history.replaceState(
    null,
    html.document.title,
    cleanUri.toString(),
  );
}
