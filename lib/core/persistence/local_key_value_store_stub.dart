import 'local_key_value_store_base.dart';

class PlatformLocalKeyValueStore implements LocalKeyValueStore {
  const PlatformLocalKeyValueStore();

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}
