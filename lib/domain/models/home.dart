import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'light.dart';

part 'home.freezed.dart';

/// The mesh network Luminar owns: its keys, addresses and lights.
@freezed
abstract class Home with _$Home {
  const Home._();

  const factory Home({
    /// Hex.
    required String netKey,

    /// Hex.
    required String appKey,
    @Default(0) int iv,

    /// Luminar's own unicast address.
    @Default(0x0001) int src,

    /// Sequence numbers below this may already have been used. Never lower it.
    @Default(1) int seq,
    @Default(0x0010) int nextAddr,
    @Default([]) List<Light> lights,

    /// Saved scene names by scene number. The web app's backups omit them.
    @Default({}) Map<int, String> scenes,
  }) = _Home;

  /// Lights that take commands.
  List<Light> get ready => [
    for (final l in lights)
      if (l.usable) l,
  ];

  /// The light added from the bulb with Bluetooth id [bleId], if any.
  Light? lightWithBleId(String bleId) {
    for (final l in lights) {
      if (l.bleId == bleId) return l;
    }
    return null;
  }

  Light? lightAt(int addr) {
    for (final l in lights) {
      if (l.addr == addr) return l;
    }
    return null;
  }

  /// This home with [addr]'s light replaced by `change(light)`.
  Home updateLight(int addr, Light Function(Light l) change) =>
      copyWith(lights: [for (final l in lights) l.addr == addr ? change(l) : l]);

  static final _key = RegExp(r'^[0-9a-fA-F]{32}$');

  factory Home.fromJson(Map<String, Object?> j) {
    if (j case {
      'netKey': final String netKey,
      'appKey': final String appKey,
      'lights': final List<Object?> lights,
    }) {
      if (!_key.hasMatch(netKey) || !_key.hasMatch(appKey)) {
        throw const FormatException('Bad key length');
      }
      int intOr(String k, int fallback) => switch (j[k]) {
        final int v => v,
        _ => fallback,
      };
      return Home(
        netKey: netKey,
        appKey: appKey,
        iv: intOr('iv', 0),
        src: intOr('src', 0x0001),
        seq: intOr('seq', 1),
        nextAddr: intOr('nextAddr', 0x0010),
        lights: [
          for (final l in lights)
            if (l is Map) Light.fromJson(l.cast<String, Object?>()),
        ],
        scenes: switch (j['scenes']) {
          final Map<Object?, Object?> m => {
            for (final e in m.entries) ?int.tryParse('${e.key}'): '${e.value}',
          },
          _ => const {},
        },
      );
    }
    throw const FormatException('Missing keys or lights');
  }

  Map<String, Object?> toJson() => {
    'v': 2,
    'netKey': netKey,
    'appKey': appKey,
    'iv': iv,
    'src': src,
    'seq': seq,
    'nextAddr': nextAddr,
    'lights': [for (final l in lights) l.toJson()],
    'scenes': {for (final e in scenes.entries) '${e.key}': e.value},
  };

  static const backupPrefix = 'LAMPLIGHT1:';

  /// Margin added to SEQ on restore, to stay ahead of every message sent
  /// since the backup was made.
  static const restoreSeqMargin = 100000;

  String toBackupCode() => backupPrefix + base64.encode(utf8.encode(jsonEncode(toJson())));

  /// Parses a backup code from this app or the Lamplight web app.
  /// Throws [FormatException] if the code is not valid.
  factory Home.fromBackupCode(String code) {
    var raw = code.trim().replaceAll(RegExp(r'\s'), '');
    if (raw.startsWith(backupPrefix)) raw = raw.substring(backupPrefix.length);
    final j = jsonDecode(utf8.decode(base64.decode(raw)));
    if (j is! Map) throw const FormatException('Not a backup code');
    final h = Home.fromJson(j.cast<String, Object?>());
    return h.copyWith(seq: h.seq + restoreSeqMargin);
  }
}
