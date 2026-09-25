import 'package:luminar/data/mesh/messages.dart';
import 'package:luminar/data/repositories/home_repository.dart';
import 'package:luminar/data/services/activity_log.dart';
import 'package:luminar/data/services/mesh_proxy_service.dart';
import 'package:luminar/domain/models/light.dart';

/// Scenes stored on the bulbs (Scene Setup Server) and their names.
class SceneRepository {
  SceneRepository({required this._proxy, required this._home, required this._log});

  final MeshProxyService _proxy;
  final HomeRepository _home;
  final ActivityLog _log;

  /// Saved scene names by scene number.
  Map<int, String> get names => _home.home.scenes;

  List<Light> _with(String model) => [
    for (final l in _home.home.ready)
      if (l.has(model)) l,
  ];

  /// Stores each light's current state as [scene] (1–65535). Returns each
  /// light's reply by address (null if it did not answer).
  Future<Map<int, SceneStatus?>> store(int scene, {List<Light>? on}) async {
    final out = <int, SceneStatus?>{};
    for (final l in on ?? _with('sceneSetup')) {
      final r = await _proxy.request(l.addr, Msg.sceneStore(scene), Op.sceneRegisterStatus);
      out[l.addr] = r == null ? null : SceneStatus.parse(r);
    }
    return out;
  }

  /// Recalls [scene] on every light with the Scene model, through the All
  /// lights group where possible. Returns the addresses it was sent to.
  Future<List<int>> recall(int scene, {Duration? transition}) async {
    final lights = _with('scene');
    try {
      final tid = _proxy.nextTid();
      final access = Msg.sceneRecall(scene, tid, transition: transition);
      await _proxy.sendEach(allLightsGroup, [
        for (final l in lights)
          (addr: l.addr, access: access, subscribed: l.groupModels.contains('scene')),
      ]);
    } catch (e) {
      _log.add('Send failed: $e');
    }
    return [for (final l in lights) l.addr];
  }

  /// Saves the lights' current state as a named scene. Returns how many
  /// lights stored it.
  Future<int> save(String name) async {
    var n = 1;
    while (names.containsKey(n)) {
      n++;
    }
    final r = await store(n);
    final ok = r.values.where((s) => s != null && s.ok).length;
    if (ok > 0) {
      final label = name.trim().isEmpty ? 'Scene $n' : name.trim();
      await _home.update((h) => h.copyWith(scenes: {...h.scenes, n: label}));
    }
    return ok;
  }

  /// Deletes [scene] from the lights (if connected) and forgets its name.
  Future<void> forget(int scene) async {
    if (_proxy.isOpen) await delete(scene);
    await _home.update((h) => h.copyWith(scenes: {...h.scenes}..remove(scene)));
  }

  Future<SceneStatus?> register(int addr) async {
    final r = await _proxy.request(addr, Msg.sceneRegisterGet(), Op.sceneRegisterStatus);
    return r == null ? null : SceneStatus.parse(r);
  }

  Future<Map<int, SceneStatus?>> delete(int scene, {List<Light>? on}) async {
    final out = <int, SceneStatus?>{};
    for (final l in on ?? _with('sceneSetup')) {
      final r = await _proxy.request(l.addr, Msg.sceneDelete(scene), Op.sceneRegisterStatus);
      out[l.addr] = r == null ? null : SceneStatus.parse(r);
    }
    return out;
  }
}
