import 'dart:js_interop';

@JS('lectorVoice.supported')
external bool get _supported;
@JS('lectorVoice.start')
external JSPromise<JSAny?> _start();
@JS('lectorVoice.finish')
external JSPromise<JSString> _finish();
@JS('lectorVoice.cancel')
external void _cancel();

/// Browser capture only. API keys and transcription remain on the server.
class GeneratorVoice {
  bool get supported {
    try {
      return _supported;
    } catch (_) {
      return false;
    }
  }

  Future<void> start() async {
    await _start().toDart;
  }

  Future<String> finish() async => (await _finish().toDart).toDart;
  void cancel() {
    try {
      _cancel();
    } catch (_) {}
  }
}
