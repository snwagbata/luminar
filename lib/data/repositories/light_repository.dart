import 'dart:async';

import 'package:dart_debounce_throttle/dart_debounce_throttle.dart';
import 'package:flutter/foundation.dart';

import 'package:luminar/data/mesh/bytes.dart';
import 'package:luminar/data/mesh/messages.dart';
import 'package:luminar/data/repositories/home_repository.dart';
import 'package:luminar/data/services/activity_log.dart';
import 'package:luminar/data/services/mesh_proxy_service.dart';
import 'package:luminar/data/services/timings.dart';
import 'package:luminar/domain/models/light.dart';
import 'package:luminar/domain/models/light_state.dart';
import 'package:luminar/domain/models/preset.dart';

/// How [LightRepository.configure] ended.
enum ConfigureResult {
  ready,

  /// The bulb did not answer AppKey Add.
  noAnswer,

  /// The bulb did not accept the AppKey on its on/off model.
  onOffRejected,
}

/// Configuration and control of the lights, and what they report back.
class LightRepository extends ChangeNotifier {
  LightRepository({
    required this._proxy,
    required this._home,
    required this._log,
    this.timings = const Timings(),
  }) {
    _statusSub = _proxy.messages.listen((m) => _onStatus(m.src, m.payload));
  }

  final MeshProxyService _proxy;
  final HomeRepository _home;
  final ActivityLog _log;
  final Timings timings;
  late final StreamSubscription<AccessMessage> _statusSub;
  final _states = <int, LightState>{};

  /// Status replies heard per light, to tell whether a query was answered.
  final _replies = <int, int>{};
  final _queryTimers = <Timer>{};

  static int toLightness(int pct) => (pct.clamp(1, 100) / 100 * 65535).round();

  List<Light> get _ready => _home.home.ready;

  LightState stateOf(int addr) => _states[addr] ?? const LightState();

  void _setState(int addr, LightState Function(LightState s) change) {
    _states[addr] = change(stateOf(addr));
  }

  /// Marks [addrs] as on until they report otherwise (e.g. after a scene
  /// recall).
  void assumeOn(Iterable<int> addrs) {
    for (final a in addrs) {
      _setState(a, (s) => s.copyWith(on: true));
    }
    notifyListeners();
  }

  void _onStatus(int src, Uint8List a) {
    final l = _home.home.lightAt(src);
    final st = LightStatus.parse(a);
    if (l == null || st == null) return;
    var on = stateOf(src).on;
    if (st.on != null) on = st.on!;
    var level = l.level, kelvin = l.kelvin;
    final lightness = st.lightness;
    if (lightness != null) {
      if (lightness > 0) level = (lightness / 65535 * 100).round().clamp(1, 100);
      // Lightness 0 means off, whichever model reported it.
      on = lightness > 0;
    }
    final k = st.kelvin;
    if (k != null && k >= 800 && k <= 20000) kelvin = k.clamp(minKelvin, maxKelvin);
    _replies[src] = (_replies[src] ?? 0) + 1;
    _setState(src, (s) => s.copyWith(on: on, known: true, responding: true));
    if (l.wasReset) {
      // It answers with our keys after all (for example, set up again in
      // another copy of Luminar).
      unawaited(_home.updateLight(src, (l) => l.copyWith(wasReset: false)));
    }
    if (level != l.level || kelvin != l.kelvin) {
      unawaited(_home.updateLight(src, (l) => l.copyWith(level: level, kelvin: kelvin)));
    }
    notifyListeners();
  }

  // ---------- configuration ----------

  /// Gives the bulb our AppKey, binds it to every model Luminar can drive
  /// and joins the All lights group.
  Future<ConfigureResult> configure(int addr, {int tries = 3}) async {
    final name = _home.home.lightAt(addr)?.name ?? hex16(addr);
    // Ask the bulb which models it has, then bind the AppKey to each one
    // Luminar knows how to drive, on the element that hosts it.
    final comp = await _proxy.ask(
      addr,
      Msg.compositionGet(),
      (s, a) => s == addr && opcodeOf(a) == Op.compositionStatus,
      device: true,
      tries: 2,
    );
    final add = await _proxy.ask(
      addr,
      Msg.appKeyAdd(hex(_home.home.appKey)),
      (s, a) => s == addr && opcodeOf(a) == Op.appKeyStatus,
      device: true,
      tries: tries,
    );
    if (add == null || !(add[2] == 0 || add[2] == 6)) return ConfigureResult.noAnswer;

    final composition = comp == null ? null : Composition.parse(comp);
    final hosts = <int, int>{}; // model id -> element address
    if (composition != null) {
      _log.add(
        'Composition of $name: CID 0x${composition.cid.toRadixString(16)} '
        'PID 0x${composition.pid.toRadixString(16)}, '
        '${composition.elements.length} element(s), models '
        '${composition.elements.map((e) => [...e.sigModels.map(hex16), ...e.vendorModels.map((v) => '0x${v.toRadixString(16).padLeft(8, '0')}')].join(' ')).join(' | ')}',
      );
      for (var i = 0; i < composition.elements.length; i++) {
        for (final m in composition.elements[i].sigModels) {
          hosts.putIfAbsent(m, () => addr + i);
        }
      }
    } else {
      _log.add('No composition data from $name; binding the basic light models');
      for (final m in [Models.onOff, Models.lightness, Models.ctl]) {
        hosts[m] = addr;
      }
    }
    final models = <String, bool>{};
    for (final m in Models.bindable.entries) {
      final element = hosts[m.value];
      if (element == null) continue;
      final r = await _proxy.ask(
        addr,
        Msg.modelAppBind(element, m.value),
        (s, a) =>
            s == addr &&
            opcodeOf(a) == Op.modelAppStatus &&
            a.length >= 9 &&
            u16le(a, 7) == m.value,
        device: true,
        tries: 3,
        timeout: timings.configReply,
      );
      models[m.key] = r != null && r[2] == 0;
    }
    final ok = models['onoff'] == true;
    await _home.updateLight(addr, (l) => l.copyWith(models: models, configured: ok));
    if (!ok) return ConfigureResult.onOffRejected;
    await joinGroup(addr);
    return ConfigureResult.ready;
  }

  /// Subscribes the light's groupable models to [allLightsGroup]. Lights keep
  /// working without it (they get their own messages), so failures are only
  /// logged.
  Future<bool> joinGroup(int addr) async {
    final l = _home.home.lightAt(addr);
    if (l == null) return false;
    for (final k in Light.groupable) {
      if (!l.has(k) || _home.home.lightAt(addr)!.groupModels.contains(k)) continue;
      final m = Models.bindable[k]!;
      if (!_proxy.isOpen) return false;
      final r = await _proxy.ask(
        addr,
        Msg.modelSubscriptionAdd(addr, allLightsGroup, m),
        (s, a) =>
            s == addr &&
            opcodeOf(a) == Op.modelSubscriptionStatus &&
            a.length >= 9 &&
            u16le(a, 7) == m,
        device: true,
        tries: 3,
        timeout: timings.configReply,
      );
      if (r == null || r[2] != 0) {
        _log.add(
          '${l.name} did not join the All lights group (model ${hex16(m)}, status ${r?[2]})',
        );
        return false;
      }
      await _home.updateLight(addr, (l) => l.copyWith(groupModels: {...l.groupModels, k}));
    }
    return true;
  }

  /// Finishes setup for unfinished lights, adds older lights to the group,
  /// and asks every light for its state.
  Future<void> syncAll() async {
    try {
      for (final l in _home.home.lights.where((l) => !l.configured && !l.wasReset).toList()) {
        if (!_proxy.isOpen) return;
        await configure(l.addr);
      }
      // Lights set up before Luminar used groups.
      for (final l in _ready.where((l) => !l.grouped).toList()) {
        if (!_proxy.isOpen) return;
        await joinGroup(l.addr);
      }
      await queryAll();
    } catch (e) {
      _log.add('After-connect setup failed: $e');
    }
  }

  // ---------- state ----------

  Future<void> _safe(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      _log.add('Send failed: $e');
    }
  }

  /// Asks the light for its on/off and level state; the replies update
  /// [stateOf] and the light's level and temperature. A light that does
  /// not answer within [Timings.configReply] is marked not responding.
  Future<void> queryState(int addr) async {
    final l = _home.home.lightAt(addr);
    if (l == null) return;
    final heard = _replies[addr] ?? 0;
    late final Timer timer;
    timer = Timer(timings.configReply, () {
      _queryTimers.remove(timer);
      if ((_replies[addr] ?? 0) == heard && _proxy.isOpen) {
        _setState(addr, (s) => s.copyWith(responding: false));
        notifyListeners();
      }
    });
    _queryTimers.add(timer);
    await _safe(() => _proxy.send(addr, Msg.onOffGet()));
    if (l.hasCtl) {
      await _safe(() => _proxy.send(addr, Msg.ctlGet()));
    } else if (l.hasLightness) {
      await _safe(() => _proxy.send(addr, Msg.lightnessGet()));
    }
  }

  Future<void> queryAll() async {
    for (final l in _ready) {
      if (!_proxy.isOpen) return;
      await queryState(l.addr);
    }
  }

  // ---------- control ----------

  /// The model and message that set [l] to its level and temperature.
  static (String, List<int>)? _levelMsg(Light l, int tid) => l.hasCtl
      ? ('ctl', Msg.ctlSet(toLightness(l.level), l.kelvin, tid))
      : l.hasLightness
      ? ('lightness', Msg.lightnessSet(toLightness(l.level), tid))
      : null;

  /// Sends each light the message [build] makes for it, through the All
  /// lights group where the light's model is subscribed.
  Future<void> _sendToAll(
    List<Light> lights,
    (String, List<int>)? Function(Light l, int tid) build,
  ) => _safe(() async {
    final tid = _proxy.nextTid();
    await _proxy.sendEach(allLightsGroup, [
      for (final l in lights)
        if (build(l, tid) case (final model, final access))
          (addr: l.addr, access: access, subscribed: l.groupModels.contains(model)),
    ]);
  });

  Future<void> setPower(int addr, bool on) async {
    _setState(addr, (s) => s.copyWith(on: on));
    notifyListeners();
    await _safe(() => _proxy.send(addr, Msg.onOffSet(on, _proxy.nextTid())));
  }

  /// Turns every light off if any is on, otherwise on.
  Future<void> toggleAll() => setAllPower(!_ready.any((l) => stateOf(l.addr).on));

  /// Turns every light on or off, in one group message where possible.
  Future<void> setAllPower(bool on) async {
    final lights = _ready;
    for (final l in lights) {
      _setState(l.addr, (s) => s.copyWith(on: on));
    }
    notifyListeners();
    await _sendToAll(lights, (l, tid) => ('onoff', Msg.onOffSet(on, tid)));
  }

  // Slider updates: send at once, then at most every [Timings.throttle],
  // always finishing with the latest value.
  final _perLight = <int, ThrottleDebouncer>{};
  late final _allThrottle = ThrottleDebouncer(duration: timings.throttle);

  Future<void> _sendLevelAll() => _sendToAll(_ready, _levelMsg);

  Light _withLevel(Light l, int? level, int? kelvin) => l.copyWith(
    level: level?.clamp(1, 100) ?? l.level,
    kelvin: kelvin?.clamp(minKelvin, maxKelvin) ?? l.kelvin,
  );

  /// Updates one light's brightness and/or temperature (from a slider).
  void setLevel(int addr, {int? level, int? kelvin}) {
    unawaited(_home.updateLight(addr, (l) => _withLevel(l, level, kelvin)));
    _setState(addr, (s) => s.copyWith(on: true));
    notifyListeners();
    _perLight
        .putIfAbsent(addr, () => ThrottleDebouncer(duration: timings.throttle))
        .call(
          () => _safe(() async {
            final l = _home.home.lightAt(addr);
            final m = l == null ? null : _levelMsg(l, _proxy.nextTid());
            if (m != null) await _proxy.send(addr, m.$2);
          }),
        );
  }

  Future<void> _setAllLevels(int? level, int? kelvin) {
    final addrs = {for (final l in _ready) l.addr};
    for (final a in addrs) {
      _setState(a, (s) => s.copyWith(on: true));
    }
    notifyListeners();
    return _home.update(
      (h) => h.copyWith(
        lights: [
          for (final l in h.lights) addrs.contains(l.addr) ? _withLevel(l, level, kelvin) : l,
        ],
      ),
    );
  }

  /// Updates every light's brightness and/or temperature (from a slider).
  void setAll({int? level, int? kelvin}) {
    unawaited(_setAllLevels(level, kelvin));
    _allThrottle.call(_sendLevelAll);
  }

  Future<void> applyPreset(Preset p) async {
    unawaited(_setAllLevels(p.level, p.kelvin));
    await _sendLevelAll();
  }

  // ---------- manage ----------

  Future<void> rename(int addr, String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    await _home.updateLight(addr, (l) => l.copyWith(name: n));
  }

  /// Resets the bulb (if connected) and forgets it.
  Future<void> remove(int addr) async {
    if (_proxy.isOpen) {
      try {
        await _proxy.ask(
          addr,
          Msg.nodeReset(),
          (s, a) => s == addr && opcodeOf(a) == Op.nodeResetStatus,
          device: true,
          tries: 2,
          timeout: const Duration(seconds: 2),
        );
      } catch (e) {
        _log.add('Reset failed: $e');
      }
    }
    _states.remove(addr);
    await _home.removeLight(addr);
  }

  /// Forgets every light's reported state (after restore or start over).
  void resetStates() {
    _states.clear();
    notifyListeners();
  }

  // ---------- CTL setup, scheduler, raw ----------

  Future<RangeStatus?> temperatureRange(int addr) async {
    final r = await _proxy.request(addr, Msg.ctlTempRangeGet(), Op.ctlTempRangeStatus);
    return r == null ? null : RangeStatus.parse(r, Op.ctlTempRangeStatus);
  }

  Future<RangeStatus?> setTemperatureRange(int addr, int minK, int maxK) async {
    final r = await _proxy.request(addr, Msg.ctlTempRangeSet(minK, maxK), Op.ctlTempRangeStatus);
    return r == null ? null : RangeStatus.parse(r, Op.ctlTempRangeStatus);
  }

  Future<CtlDefault?> ctlDefault(int addr) async {
    final r = await _proxy.request(addr, Msg.ctlDefaultGet(), Op.ctlDefaultStatus);
    return r == null ? null : CtlDefault.parse(r);
  }

  /// Sets the brightness (1–100 %) and temperature the bulb uses as its
  /// default state.
  Future<CtlDefault?> setCtlDefault(int addr, int level, int kelvin) async {
    final r = await _proxy.request(
      addr,
      Msg.ctlDefaultSet(toLightness(level), kelvin),
      Op.ctlDefaultStatus,
    );
    return r == null ? null : CtlDefault.parse(r);
  }

  Future<RangeStatus?> lightnessRange(int addr) async {
    final r = await _proxy.request(addr, Msg.lightnessRangeGet(), Op.lightnessRangeStatus);
    return r == null ? null : RangeStatus.parse(r, Op.lightnessRangeStatus);
  }

  /// Schedule slots (0–15) in use on the light.
  Future<List<int>?> schedules(int addr) async {
    final r = await _proxy.request(addr, Msg.schedulerGet(), Op.schedulerStatus);
    return r == null ? null : parseSchedulerStatus(r);
  }

  Future<ScheduleEntry?> scheduleAction(int addr, int index) async {
    final r = await _proxy.request(addr, Msg.schedulerActionGet(index), Op.schedulerActionStatus);
    return r == null ? null : ScheduleEntry.parse(r);
  }

  Future<ScheduleEntry?> setScheduleAction(int addr, ScheduleEntry e) async {
    final r = await _proxy.request(addr, Msg.schedulerActionSet(e), Op.schedulerActionStatus);
    return r == null ? null : ScheduleEntry.parse(r);
  }

  /// Sends raw access bytes with the AppKey, e.g. for the vendor model.
  /// Waits for a reply with [replyOp] if given.
  Future<Uint8List?> sendRaw(int addr, List<int> access, {int? replyOp}) async {
    if (replyOp != null) return _proxy.request(addr, access, replyOp);
    await _safe(() => _proxy.send(addr, access));
    return null;
  }

  @override
  void dispose() {
    for (final t in _queryTimers) {
      t.cancel();
    }
    _statusSub.cancel();
    _allThrottle.dispose();
    for (final t in _perLight.values) {
      t.dispose();
    }
    super.dispose();
  }
}
