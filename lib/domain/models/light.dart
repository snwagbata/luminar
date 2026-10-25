import 'package:freezed_annotation/freezed_annotation.dart';

part 'light.freezed.dart';

const minKelvin = 2700, maxKelvin = 6500;

/// Group address every light's on/off, brightness, temperature and scene
/// models subscribe to, so one message reaches all lights at once.
const allLightsGroup = 0xC000;

/// One provisioned bulb. JSON field names match the web app's backup format.
@freezed
abstract class Light with _$Light {
  const Light._();

  const factory Light({
    required int addr,
    @Default(1) int elements,
    required String name,

    /// Hex.
    required String devKey,
    @Default(false) bool configured,

    /// Models the AppKey is bound to, by key of `Models.bindable`.
    @Default({}) Map<String, bool> models,

    /// 1–100 %.
    @Default(70) int level,
    @Default(3000) int kelvin,

    /// Models (keys of `Models.bindable`) subscribed to [allLightsGroup].
    @Default({}) Set<String> groupModels,

    /// Platform Bluetooth id (MAC on Android), if known. Not in web backups.
    String? bleId,

    /// The bulb was seen advertising as a new bulb: it was reset outside
    /// Luminar and has forgotten the network.
    @Default(false) bool wasReset,
  }) = _Light;

  /// Models that join [allLightsGroup], so all-lights commands and scene
  /// recalls reach every bulb in one message.
  static const groupable = ['onoff', 'lightness', 'ctl', 'scene'];

  bool has(String model) => models[model] == true;

  /// Set up and still on the network, so it takes commands.
  bool get usable => configured && !wasReset;
  bool get hasCtl => has('ctl');
  bool get hasLightness => has('lightness');

  /// Whether every groupable model this light has is in [allLightsGroup].
  bool get grouped => groupable.every((k) => !has(k) || groupModels.contains(k));

  factory Light.fromJson(Map<String, Object?> j) {
    if (j case {'addr': final int addr, 'devKey': final String devKey}) {
      return Light(
        addr: addr,
        elements: switch (j['elements']) {
          final int e => e,
          _ => 1,
        },
        name: switch (j['name']) {
          final String n => n,
          _ => 'Light',
        },
        devKey: devKey,
        configured: j['configured'] == true,
        models: switch (j['models']) {
          final Map<Object?, Object?> m => {for (final e in m.entries) '${e.key}': e.value == true},
          _ => const {},
        },
        level: switch (j['level']) {
          final num v => v.round().clamp(1, 100),
          _ => 70,
        },
        kelvin: switch (j['kelvin']) {
          final num v => v.round().clamp(minKelvin, maxKelvin),
          _ => 3000,
        },
        groupModels: {
          if (j['groupModels'] case final List<Object?> g) ...g.whereType<String>(),
          // Written by builds that grouped only the light models.
          if (j['grouped'] == true) ...['onoff', 'lightness', 'ctl'],
        },
        bleId: switch (j['bleId']) {
          final String id => id,
          _ => null,
        },
        wasReset: j['wasReset'] == true,
      );
    }
    throw const FormatException('A light needs an address and a device key');
  }

  Map<String, Object?> toJson() => {
    'addr': addr,
    'elements': elements,
    'name': name,
    'devKey': devKey,
    'configured': configured,
    'models': models,
    'level': level,
    'kelvin': kelvin,
    'groupModels': groupModels.toList(),
    if (bleId != null) 'bleId': bleId,
    if (wasReset) 'wasReset': true,
  };
}
