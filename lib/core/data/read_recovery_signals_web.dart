// Matches the existing browser bridges; no platform dependency on mobile.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void Function() listenForConnectionReturn(void Function() callback) {
  final subscription = html.window.onOnline.listen((_) => callback());
  return () => subscription.cancel();
}
