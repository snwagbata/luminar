import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:luminar/data/mesh/bytes.dart';
import 'package:luminar/data/mesh/network.dart';
import 'package:luminar/data/services/activity_log.dart';
import 'package:luminar/data/services/home_store.dart';
import 'package:luminar/data/services/mesh_proxy_service.dart';
import 'package:luminar/domain/models/home.dart';
import 'package:luminar/domain/models/light.dart';

/// The single source of truth for the home: network keys, lights and
/// scene names. Persists every change and hands out sequence numbers.
class HomeRepository extends ChangeNotifier implements MeshKeyring {
  HomeRepository({required this._store, required this._log});

  final HomeStore _store;
  final ActivityLog _log;

  Home? _home;
  late NetKeys _netKeys;
  final _devKeys = <int, Uint8List>{};
  int _seq = 1;

  bool get loaded => _home != null;
  Home get home => _home!;

  static Home _create() => Home(netKey: toHex(randomBytes(16)), appKey: toHex(randomBytes(16)));

  Future<void> load() async {
    Home? h;
    try {
      final raw = await _store.load();
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is Map) h = Home.fromJson(j.cast<String, Object?>());
      }
    } catch (e) {
      _log.add('Could not read saved lights: $e');
    }
    await _replace(h ?? _create());
  }

  /// Replaces the whole home (restore, start over) and saves it at once.
  Future<void> _replace(Home h) async {
    _home = h;
    _netKeys = NetKeys.derive(hex(h.netKey), hex(h.appKey));
    _syncDevKeys();
    _seq = h.seq;
    await _saveNow();
    notifyListeners();
  }

  void _syncDevKeys() {
    _devKeys
      ..clear()
      ..addEntries(home.lights.map((l) => MapEntry(l.addr, hex(l.devKey))));
  }

  /// Applies [change] to the home, then saves and notifies.
  Future<void> update(Home Function(Home h) change) {
    final before = home;
    _home = change(before);
    if (!identical(before.lights, home.lights)) _syncDevKeys();
    notifyListeners();
    return save();
  }

  Future<void> updateLight(int addr, Light Function(Light l) change) =>
      update((h) => h.updateLight(addr, change));

  /// Adds a newly provisioned light that uses [elements] addresses.
  Future<void> addLight(Light light) => update(
    (h) => h.copyWith(
      lights: [...h.lights, light],
      nextAddr: light.addr + (light.elements < 1 ? 1 : light.elements),
    ),
  );

  /// Replaces the light at [oldAddr] (a bulb that was reset and set up
  /// again) with [light], in the same place in the list.
  Future<void> replaceLight(int oldAddr, Light light) => update(
    (h) => h.copyWith(
      lights: [for (final l in h.lights) l.addr == oldAddr ? light : l],
      nextAddr: light.addr + (light.elements < 1 ? 1 : light.elements),
    ),
  );

  Future<void> removeLight(int addr) =>
      update((h) => h.copyWith(lights: [...h.lights.where((l) => l.addr != addr)]));

  // ---------- persistence ----------

  Future<void>? _saving;
  bool _dirty = false;

  /// Persists the home. Coalesces bursts: while a write is in flight,
  /// further calls share it and trigger one more write afterwards.
  Future<void> save() {
    _dirty = true;
    return _saving ??= _flush();
  }

  Future<void> _flush() async {
    try {
      while (_dirty) {
        _dirty = false;
        await _saveNow();
      }
    } finally {
      _saving = null;
    }
  }

  Future<void> _saveNow() async {
    try {
      await _store.save(jsonEncode(home.toJson()));
    } catch (e) {
      _log.add('Save failed: $e');
    }
  }

  // ---------- backup ----------

  String backupCode() {
    if (_seq > home.seq) _home = home.copyWith(seq: _seq);
    return home.toBackupCode();
  }

  /// Replaces the home with a backup. Throws [FormatException] if invalid.
  Future<void> restore(String code) => _replace(Home.fromBackupCode(code));

  /// Forgets every light and starts a new network.
  Future<void> startOver() => _replace(_create());

  // ---------- MeshKeyring ----------

  static const _seqReserve = 64;

  @override
  NetKeys get netKeys => _netKeys;

  @override
  int get src => home.src;

  @override
  int get iv => home.iv;

  @override
  void updateIv(int iv) => unawaited(update((h) => h.copyWith(iv: iv)));

  @override
  Uint8List? deviceKey(int addr) => _devKeys[addr];

  /// Returns a never-before-used SEQ. Persists a reservation ahead of use so
  /// a crash can never make SEQ go backwards.
  @override
  int nextSeq() {
    final s = _seq++;
    if (s > 0xffffff) throw StateError('Sequence numbers exhausted');
    if (_seq > home.seq) {
      _home = home.copyWith(seq: _seq + _seqReserve);
      save();
    }
    return s;
  }
}
