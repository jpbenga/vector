// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

bool launchExternalLink(Uri uri) {
  html.window.open(uri.toString(), '_self');
  return true;
}
