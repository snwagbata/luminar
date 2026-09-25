import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/data/services/home_store.dart';
import 'package:luminar/domain/models/home.dart';

import '../../support/harness.dart';
import '../../support/mock_bulb.dart';

void main() {
  test('SEQ never goes backwards across restarts', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
    final ble = FakeBle([bulb]);
    final store = MemoryHomeStore();
    final h = await Harness.start(ble, store);
    await h.add(bulb);
    await settle();
    expect(bulb.received.length, greaterThan(3));
    final saved = jsonDecode(store.value!) as Map<String, dynamic>;
    await h.connection.disconnect();

    // A new app on the same store starts at or above the reservation.
    final h2 = await Harness.start(ble, store);
    expect(h2.home.home.seq, greaterThanOrEqualTo(saved['seq'] as int));
    await h2.vm.connect();
    expect(h2.vm.isConnected, isTrue, reason: h2.vm.status);
    final before = bulb.on;
    await h2.vm.setPower(h2.single, !before);
    await settle();
    expect(bulb.on, !before, reason: 'bulb accepted the message (no replay drop)');
  });

  test('scene names survive a restart', () async {
    final store = MemoryHomeStore();
    final h = await Harness.start(FakeBle([]), store);
    await h.home.update((x) => x.copyWith(scenes: {1: 'Evening'}));
    final h2 = await Harness.start(FakeBle([]), store);
    expect(h2.home.home.scenes, {1: 'Evening'});
  });

  test('a new home gets random keys and is saved at once', () async {
    final store = MemoryHomeStore();
    final h = await Harness.start(FakeBle([]), store);
    expect(h.home.home.netKey, hasLength(32));
    expect(h.home.home.netKey, isNot(h.home.home.appKey));
    expect(store.value, isNotNull);
  });

  test('unreadable saved data starts a new home and says so', () async {
    final h = await Harness.start(FakeBle([]), MemoryHomeStore('{not json'));
    expect(h.home.home.lights, isEmpty);
    expect(h.log.text, contains('Could not read saved lights'));
  });

  test('backup and restore round trip, with a SEQ margin', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
    final h = await Harness.start(FakeBle([bulb]));
    await h.add(bulb);
    final code = h.home.backupCode();
    expect(code, startsWith(Home.backupPrefix));
    final seq = h.home.home.seq;

    final h2 = await Harness.start(FakeBle([bulb]));
    expect(await h2.vm.restore(code), isTrue);
    expect(h2.all, hasLength(1));
    expect(h2.home.home.netKey, h.home.home.netKey);
    expect(h2.home.home.seq, seq + Home.restoreSeqMargin);
    await h2.vm.connect();
    expect(h2.vm.isConnected, isTrue, reason: h2.vm.status);
    await h2.vm.setPower(h2.single, true);
    await settle();
    expect(bulb.on, isTrue);
  });
}
