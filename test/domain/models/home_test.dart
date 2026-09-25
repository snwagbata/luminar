import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/domain/models/home.dart';
import 'package:luminar/domain/models/light.dart';

void main() {
  const netKey = '00112233445566778899aabbccddeeff';
  const appKey = '0f1e2d3c4b5a69788796a5b4c3d2e1f0';

  test('reads a backup code from the Lamplight web app', () {
    final web = {
      'v': 2,
      'netKey': netKey,
      'appKey': appKey,
      'iv': 0,
      'src': 1,
      'seq': 42,
      'nextAddr': 0x11,
      'lights': [
        {
          'addr': 0x10,
          'elements': 1,
          'name': 'Lamp',
          'devKey': 'a1a2a3a4a5a6a7a8a9aaabacadaeafb0',
          'configured': true,
          'models': {'onoff': true, 'lightness': true, 'ctl': true},
          'level': 70,
          'kelvin': 3000,
        },
      ],
    };
    final h = Home.fromBackupCode('LAMPLIGHT1:${base64.encode(utf8.encode(jsonEncode(web)))}');
    expect(h.lights.single.name, 'Lamp');
    expect(h.lights.single.hasCtl, isTrue);
    expect(h.seq, 42 + Home.restoreSeqMargin);
  });

  test('rejects codes that are not backups', () {
    expect(() => Home.fromBackupCode('LAMPLIGHT1:nope'), throwsFormatException);
    final noKeys = base64.encode(utf8.encode(jsonEncode({'lights': <Object>[]})));
    expect(() => Home.fromBackupCode(noKeys), throwsFormatException);
    final shortKey = base64.encode(
      utf8.encode(jsonEncode({'netKey': 'abcd', 'appKey': appKey, 'lights': <Object>[]})),
    );
    expect(() => Home.fromBackupCode(shortKey), throwsFormatException);
  });

  test('saves scene names', () {
    final h = const Home(netKey: netKey, appKey: appKey, scenes: {1: 'Evening', 3: 'Movie'});
    final back = Home.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, Object?>);
    expect(back.scenes, {1: 'Evening', 3: 'Movie'});
    expect(back, h);
  });

  test('updateLight replaces one light', () {
    const a = Light(addr: 0x10, name: 'A', devKey: 'aa');
    const b = Light(addr: 0x11, name: 'B', devKey: 'bb');
    final h = const Home(netKey: netKey, appKey: appKey, lights: [a, b]);
    final h2 = h.updateLight(0x11, (l) => l.copyWith(name: 'Desk'));
    expect(h2.lights.map((l) => l.name), ['A', 'Desk']);
    expect(h.lights.map((l) => l.name), ['A', 'B'], reason: 'the original is unchanged');
    expect(h2.lightAt(0x11)!.name, 'Desk');
    expect(h2.lightAt(0x12), isNull);
  });

  group('Light', () {
    test('lights grouped by an older build still need their scene model', () {
      final l = Light.fromJson({
        'addr': 0x12,
        'devKey': '00' * 16,
        'configured': true,
        'models': {'onoff': true, 'lightness': true, 'ctl': true, 'scene': true},
        'grouped': true,
      });
      expect(l.groupModels, {'onoff', 'lightness', 'ctl'});
      expect(l.grouped, isFalse);
      final done = l.copyWith(groupModels: {...l.groupModels, 'scene'});
      expect(Light.fromJson(done.toJson()).grouped, isTrue);
    });

    test('a reset light is saved as such and takes no commands', () {
      const l = Light(addr: 1, name: 'x', devKey: 'aa', configured: true, wasReset: true);
      expect(Light.fromJson(l.toJson()).wasReset, isTrue);
      expect(Light.fromJson({'addr': 1, 'devKey': 'aa'}).wasReset, isFalse);
      final h = const Home(netKey: netKey, appKey: appKey, lights: [l]);
      expect(h.ready, isEmpty);
      expect(h.copyWith(lights: [l.copyWith(wasReset: false)]).ready, hasLength(1));
    });

    test('clamps level and temperature from JSON', () {
      final l = Light.fromJson({'addr': 1, 'devKey': 'aa', 'level': 400, 'kelvin': 100});
      expect([l.level, l.kelvin], [100, minKelvin]);
      expect(() => Light.fromJson({'name': 'x'}), throwsFormatException);
    });

    test('is immutable', () {
      const l = Light(addr: 1, name: 'x', devKey: 'aa', models: {'ctl': true});
      expect(() => l.models['onoff'] = true, throwsUnsupportedError);
    });
  });
}
