// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

void cleanTemporaryAccessLinkUrl() {
  final uri = Uri.base;
  if (!uri.queryParameters.containsKey('tester_token')) {
    return;
  }

  final cleanParameters = Map<String, String>.of(uri.queryParameters)
    ..remove('tester_token');
  final cleanUri = uri.replace(
    queryParameters: cleanParameters.isEmpty ? null : cleanParameters,
    fragment: '',
  );
  html.window.history.replaceState(
    null,
    html.document.title,
    cleanUri.toString(),
  );
}
