import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the home's JSON is persisted.
abstract class HomeStore {
  Future<String?> load();
  Future<void> save(String json);
}

/// Keeps the home (which holds the network keys) in the platform keystore.
class SecureHomeStore implements HomeStore {
  static const _key = 'luminar.home.v2';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> load() => _storage.read(key: _key);

  @override
  Future<void> save(String json) => _storage.write(key: _key, value: json);
}

class MemoryHomeStore implements HomeStore {
  String? value;
  MemoryHomeStore([this.value]);

  @override
  Future<String?> load() async => value;

  @override
  Future<void> save(String json) async => value = json;
}
