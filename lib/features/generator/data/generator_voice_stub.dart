class GeneratorVoice {
  bool get supported => false;
  Future<void> start() async =>
      throw StateError('Utilisez la dictée du clavier de votre appareil.');
  Future<String> finish() async => '';
  void cancel() {}
}
