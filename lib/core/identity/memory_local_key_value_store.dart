import '../persistence/local_key_value_store_base.dart';

class MemoryLocalKeyValueStore implements LocalKeyValueStore {
  MemoryLocalKeyValueStore([Map<String, String>? initialValues])
    : values = {...?initialValues};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
