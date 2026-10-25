import 'dart:typed_data';

import 'package:luminar/data/mesh/bytes.dart';

// Access-layer opcodes and parameters for every SIG model the Sengled bulbs
// expose (Mesh Model spec 1.1). Access-message parameters are little-endian.

abstract final class Models {
  static const configServer = 0x0000;
  static const onOff = 0x1000;
  static const lightness = 0x1300;
  static const ctl = 0x1303;
  static const ctlSetup = 0x1304;
  static const scene = 0x1203;
  static const sceneSetup = 0x1204;
  static const scheduler = 0x1206;
  static const schedulerSetup = 0x1207;
  static const time = 0x1200;

  /// Models Luminar binds its AppKey to, by the key stored in [Light.models].
  static const bindable = {
    'onoff': onOff,
    'lightness': lightness,
    'ctl': ctl,
    'ctlSetup': ctlSetup,
    'scene': scene,
    'sceneSetup': sceneSetup,
    'scheduler': scheduler,
    'schedulerSetup': schedulerSetup,
  };
}

abstract final class Op {
  // Configuration
  static const appKeyAdd = 0x00;
  static const appKeyStatus = 0x8003;
  static const compositionGet = 0x8008;
  static const compositionStatus = 0x02;
  static const modelAppBind = 0x803D;
  static const modelAppStatus = 0x803E;
  static const modelSubscriptionAdd = 0x801B;
  static const modelSubscriptionStatus = 0x801F;
  static const nodeReset = 0x8049;
  static const nodeResetStatus = 0x804A;

  // Generic OnOff
  static const onOffGet = 0x8201;
  static const onOffSet = 0x8202;
  static const onOffSetUnack = 0x8203;
  static const onOffStatus = 0x8204;

  // Light Lightness
  static const lightnessGet = 0x824B;
  static const lightnessSet = 0x824C;
  static const lightnessSetUnack = 0x824D;
  static const lightnessStatus = 0x824E;
  static const lightnessLinearGet = 0x824F;
  static const lightnessLinearStatus = 0x8252;
  static const lightnessLastGet = 0x8253;
  static const lightnessLastStatus = 0x8254;
  static const lightnessDefaultGet = 0x8255;
  static const lightnessDefaultStatus = 0x8256;
  static const lightnessRangeGet = 0x8257;
  static const lightnessRangeStatus = 0x8258;

  // Light CTL and CTL Setup
  static const ctlGet = 0x825D;
  static const ctlSet = 0x825E;
  static const ctlSetUnack = 0x825F;
  static const ctlStatus = 0x8260;
  static const ctlTempRangeGet = 0x8262;
  static const ctlTempRangeStatus = 0x8263;
  static const ctlDefaultGet = 0x8267;
  static const ctlDefaultStatus = 0x8268;
  static const ctlDefaultSet = 0x8269;
  static const ctlTempRangeSet = 0x826B;

  // Scene and Scene Setup
  static const sceneGet = 0x8241;
  static const sceneRecall = 0x8242;
  static const sceneRecallUnack = 0x8243;
  static const sceneStatus = 0x5E;
  static const sceneRegisterGet = 0x8244;
  static const sceneRegisterStatus = 0x8245;
  static const sceneStore = 0x8246;
  static const sceneDelete = 0x829E;

  // Scheduler and Scheduler Setup
  static const schedulerActionGet = 0x8248;
  static const schedulerActionStatus = 0x5F;
  static const schedulerGet = 0x8249;
  static const schedulerStatus = 0x824A;
  static const schedulerActionSet = 0x60;
}

/// The opcode of an access payload (1- or 2-byte opcodes; 3-byte vendor
/// opcodes return their first byte's class, 0xC0–0xFF).
int opcodeOf(List<int> a) {
  if (a.isEmpty) return -1;
  if (a[0] & 0x80 == 0) return a[0];
  if (a[0] & 0xC0 == 0xC0) return a.length >= 3 ? (a[0] << 16) | (a[1] << 8) | a[2] : -1;
  if (a.length < 2) return -1;
  return (a[0] << 8) | a[1];
}

List<int> _op(int op) => op > 0xff ? [op >> 8, op & 0xff] : [op];

/// Generic Default Transition Time encoding (steps + resolution).
int transitionTime(Duration d) {
  final ms = d.inMilliseconds;
  if (ms <= 0) return 0;
  const res = [100, 1000, 10000, 600000];
  for (var r = 0; r < 4; r++) {
    final steps = (ms / res[r]).round();
    if (steps <= 0x3e) return (r << 6) | steps.clamp(1, 0x3e);
  }
  return (3 << 6) | 0x3e;
}

abstract final class Msg {
  // ---------- configuration ----------

  /// Config AppKey Add, NetKeyIndex and AppKeyIndex packed into 3 bytes.
  static List<int> appKeyAdd(List<int> appKey, {int netKeyIndex = 0, int appKeyIndex = 0}) => [
    Op.appKeyAdd,
    netKeyIndex & 0xff,
    ((netKeyIndex >> 8) & 0x0f) | ((appKeyIndex & 0x0f) << 4),
    (appKeyIndex >> 4) & 0xff,
    ...appKey,
  ];

  static List<int> compositionGet([int page = 0]) => [..._op(Op.compositionGet), page];

  static List<int> modelAppBind(int element, int model, {int appKeyIndex = 0}) => [
    ..._op(Op.modelAppBind),
    ...le16(element),
    ...le16(appKeyIndex),
    ...le16(model),
  ];

  /// Config Model Subscription Add (SIG model on [element]).
  static List<int> modelSubscriptionAdd(int element, int group, int model) => [
    ..._op(Op.modelSubscriptionAdd),
    ...le16(element),
    ...le16(group),
    ...le16(model),
  ];

  static List<int> nodeReset() => _op(Op.nodeReset);

  // ---------- Generic OnOff ----------

  static List<int> onOffGet() => _op(Op.onOffGet);
  static List<int> onOffSet(bool on, int tid, {bool ack = false, Duration? transition}) => [
    ..._op(ack ? Op.onOffSet : Op.onOffSetUnack),
    on ? 1 : 0,
    tid & 0xff,
    if (transition != null) ...[transitionTime(transition), 0],
  ];

  // ---------- Light Lightness ----------

  static List<int> lightnessGet() => _op(Op.lightnessGet);
  static List<int> lightnessSet(int lightness, int tid, {bool ack = false, Duration? transition}) =>
      [
        ..._op(ack ? Op.lightnessSet : Op.lightnessSetUnack),
        ...le16(lightness),
        tid & 0xff,
        if (transition != null) ...[transitionTime(transition), 0],
      ];
  static List<int> lightnessLinearGet() => _op(Op.lightnessLinearGet);
  static List<int> lightnessLastGet() => _op(Op.lightnessLastGet);
  static List<int> lightnessDefaultGet() => _op(Op.lightnessDefaultGet);

  // ---------- Light CTL ----------

  static List<int> ctlGet() => _op(Op.ctlGet);
  static List<int> ctlSet(
    int lightness,
    int kelvin,
    int tid, {
    bool ack = false,
    Duration? transition,
  }) => [
    ..._op(ack ? Op.ctlSet : Op.ctlSetUnack),
    ...le16(lightness),
    ...le16(kelvin),
    0, 0, // delta UV
    tid & 0xff,
    if (transition != null) ...[transitionTime(transition), 0],
  ];
  static List<int> ctlTempRangeGet() => _op(Op.ctlTempRangeGet);
  static List<int> ctlDefaultGet() => _op(Op.ctlDefaultGet);

  /// CTL Setup: the state used at power-up when OnPowerUp says "default".
  static List<int> ctlDefaultSet(int lightness, int kelvin) => [
    ..._op(Op.ctlDefaultSet),
    ...le16(lightness),
    ...le16(kelvin),
    0,
    0,
  ];

  /// CTL Setup: limits for the temperature the bulb accepts.
  static List<int> ctlTempRangeSet(int minK, int maxK) => [
    ..._op(Op.ctlTempRangeSet),
    ...le16(minK),
    ...le16(maxK),
  ];

  // ---------- Scene ----------

  static List<int> sceneGet() => _op(Op.sceneGet);
  static List<int> sceneRegisterGet() => _op(Op.sceneRegisterGet);

  /// Scene numbers are 1–65535; 0 is prohibited.
  static List<int> sceneStore(int scene) => [..._op(Op.sceneStore), ...le16(_scene(scene))];
  static List<int> sceneRecall(int scene, int tid, {bool ack = false, Duration? transition}) => [
    ..._op(ack ? Op.sceneRecall : Op.sceneRecallUnack),
    ...le16(_scene(scene)),
    tid & 0xff,
    if (transition != null) ...[transitionTime(transition), 0],
  ];
  static List<int> sceneDelete(int scene) => [..._op(Op.sceneDelete), ...le16(_scene(scene))];

  static int _scene(int n) {
    if (n < 1 || n > 0xffff) throw RangeError.range(n, 1, 0xffff, 'scene');
    return n;
  }

  // ---------- Scheduler ----------

  static List<int> schedulerGet() => _op(Op.schedulerGet);
  static List<int> schedulerActionGet(int index) => [..._op(Op.schedulerActionGet), index & 0x0f];
  static List<int> schedulerActionSet(ScheduleEntry e) => [
    ..._op(Op.schedulerActionSet),
    ...e.encode(),
  ];
}

/// A light state report parsed from a status message.
class LightStatus {
  final bool? on;

  /// 0–65535, or null if not reported.
  final int? lightness;
  final int? kelvin;
  LightStatus({this.on, this.lightness, this.kelvin});

  /// Parses OnOff, Lightness and CTL status messages. Uses the target value
  /// when a transition is in progress.
  static LightStatus? parse(List<int> a) {
    switch (opcodeOf(a)) {
      case Op.onOffStatus when a.length >= 3:
        return LightStatus(on: (a.length > 3 ? a[3] : a[2]) != 0);
      case Op.lightnessStatus when a.length >= 4:
        return LightStatus(lightness: a.length >= 6 ? u16le(a, 4) : u16le(a, 2));
      case Op.ctlStatus when a.length >= 6:
        final target = a.length >= 11;
        return LightStatus(
          lightness: target ? u16le(a, 6) : u16le(a, 2),
          kelvin: target ? u16le(a, 8) : u16le(a, 4),
        );
    }
    return null;
  }
}

/// A min/max range with a status code (Lightness Range, CTL Temperature Range).
class RangeStatus {
  final int status, min, max;
  RangeStatus(this.status, this.min, this.max);
  bool get ok => status == 0;

  static RangeStatus? parse(List<int> a, int opcode) {
    if (opcodeOf(a) != opcode || a.length < 7) return null;
    return RangeStatus(a[2], u16le(a, 3), u16le(a, 5));
  }
}

/// Light CTL Default Status.
class CtlDefault {
  final int lightness, kelvin;
  CtlDefault(this.lightness, this.kelvin);
  static CtlDefault? parse(List<int> a) {
    if (opcodeOf(a) != Op.ctlDefaultStatus || a.length < 8) return null;
    return CtlDefault(u16le(a, 2), u16le(a, 4));
  }
}

/// Scene Status and Scene Register Status.
class SceneStatus {
  /// 0 success, 1 register full, 2 not found.
  final int status;
  final int current;
  final int? target;

  /// Stored scenes (Register Status only).
  final List<int> scenes;
  SceneStatus(this.status, this.current, {this.target, this.scenes = const []});
  bool get ok => status == 0;

  static SceneStatus? parse(List<int> a) {
    final op = opcodeOf(a);
    if (op == Op.sceneStatus && a.length >= 4) {
      return SceneStatus(a[1], u16le(a, 2), target: a.length >= 6 ? u16le(a, 4) : null);
    }
    if (op == Op.sceneRegisterStatus && a.length >= 5) {
      return SceneStatus(
        a[2],
        u16le(a, 3),
        scenes: [for (var i = 5; i + 1 < a.length; i += 2) u16le(a, i)],
      );
    }
    return null;
  }
}

/// Scheduler Status: which of the 16 schedule slots are in use.
List<int>? parseSchedulerStatus(List<int> a) {
  if (opcodeOf(a) != Op.schedulerStatus || a.length < 4) return null;
  final bits = u16le(a, 2);
  return [
    for (var i = 0; i < 16; i++)
      if (bits & (1 << i) != 0) i,
  ];
}

enum ScheduleAction {
  off(0),
  on(1),
  sceneRecall(2),
  none(0xf);

  final int code;
  const ScheduleAction(this.code);
  static ScheduleAction from(int c) => values.firstWhere((v) => v.code == c, orElse: () => none);
}

/// One Scheduler Register entry (Mesh Model spec 5.1.4.2), 80 bits packed
/// least-significant bit first.
class ScheduleEntry {
  static const anyYear = 0x64, anyHour = 0x18, anyMinute = 0x3c, anySecond = 0x3c;

  final int index; // 0–15
  final int year; // 0–99 (2000+), or anyYear
  final int months; // bit 0 = January; 0xfff = every month
  final int day; // 1–31, or 0 for any day
  final int hour; // 0–23, anyHour, or 0x19 (once a day, random)
  final int minute; // 0–59, anyMinute, 0x3d every 15, 0x3e every 20, 0x3f random
  final int second; // same encoding as minute
  final int weekdays; // bit 0 = Monday; 0x7f = every day
  final ScheduleAction action;
  final int transition; // Generic transition time byte
  final int scene; // for sceneRecall

  const ScheduleEntry({
    required this.index,
    this.year = anyYear,
    this.months = 0xfff,
    this.day = 0,
    required this.hour,
    required this.minute,
    this.second = 0,
    this.weekdays = 0x7f,
    required this.action,
    this.transition = 0,
    this.scene = 0,
  });

  Uint8List encode() {
    final w = _Bits();
    w.put(index, 4);
    w.put(year, 7);
    w.put(months, 12);
    w.put(day, 5);
    w.put(hour, 5);
    w.put(minute, 6);
    w.put(second, 6);
    w.put(weekdays, 7);
    w.put(action.code, 4);
    w.put(transition, 8);
    w.put(scene, 16);
    return w.bytes;
  }

  /// Parses a Scheduler Action Status message (or its 10-byte parameters).
  static ScheduleEntry? parse(List<int> a) {
    var p = a;
    if (a.length == 11 && opcodeOf(a) == Op.schedulerActionStatus) p = a.sublist(1);
    if (p.length != 10) return null;
    final r = _Bits(p);
    return ScheduleEntry(
      index: r.take(4),
      year: r.take(7),
      months: r.take(12),
      day: r.take(5),
      hour: r.take(5),
      minute: r.take(6),
      second: r.take(6),
      weekdays: r.take(7),
      action: ScheduleAction.from(r.take(4)),
      transition: r.take(8),
      scene: r.take(16),
    );
  }
}

class _Bits {
  final Uint8List bytes;
  int _pos = 0;
  _Bits([List<int>? src]) : bytes = Uint8List.fromList(src ?? List.filled(10, 0));

  void put(int v, int n) {
    for (var i = 0; i < n; i++, _pos++) {
      if ((v >> i) & 1 == 1) bytes[_pos >> 3] |= 1 << (_pos & 7);
    }
  }

  int take(int n) {
    var v = 0;
    for (var i = 0; i < n; i++, _pos++) {
      if ((bytes[_pos >> 3] >> (_pos & 7)) & 1 == 1) v |= 1 << i;
    }
    return v;
  }
}

/// Composition Data page 0.
class Composition {
  final int cid, pid, vid, crpl, features;
  final List<CompositionElement> elements;
  Composition(this.cid, this.pid, this.vid, this.crpl, this.features, this.elements);

  Set<int> get sigModels => {for (final e in elements) ...e.sigModels};

  /// Parses a Config Composition Data Status message.
  static Composition? parse(List<int> a) {
    if (opcodeOf(a) != Op.compositionStatus || a.length < 12 || a[1] != 0) return null;
    var i = 2;
    int u16() {
      final v = u16le(a, i);
      i += 2;
      return v;
    }

    final cid = u16(), pid = u16(), vid = u16(), crpl = u16(), features = u16();
    final elements = <CompositionElement>[];
    while (i + 4 <= a.length) {
      final loc = u16();
      final numS = a[i], numV = a[i + 1];
      i += 2;
      if (i + numS * 2 + numV * 4 > a.length) return null;
      final sig = [for (var k = 0; k < numS; k++) u16()];
      final vendor = <int>[];
      for (var k = 0; k < numV; k++) {
        final company = u16(), model = u16();
        vendor.add((company << 16) | model);
      }
      elements.add(CompositionElement(loc, sig, vendor));
    }
    return Composition(cid, pid, vid, crpl, features, elements);
  }
}

class CompositionElement {
  final int location;
  final List<int> sigModels;

  /// (company << 16) | model id.
  final List<int> vendorModels;
  CompositionElement(this.location, this.sigModels, this.vendorModels);
}
