import 'package:luminar/data/repositories/connection_repository.dart';
import 'package:luminar/data/repositories/light_repository.dart';

/// Connects to the mesh, then brings every light up to date: finishes
/// interrupted setups, joins older lights to the group and reads states.
class ConnectUseCase {
  ConnectUseCase({required this._connection, required this._lights});

  final ConnectionRepository _connection;
  final LightRepository _lights;

  Future<ConnectResult> call() async {
    final r = await _connection.connect();
    if (r is Connected) await _lights.syncAll();
    return r;
  }
}
