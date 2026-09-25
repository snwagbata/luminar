import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';
import '../../support/mock_bulb.dart';

void main() {
  test('labels a reset bulb with the light it was, and marks that light', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_A9CB');
    final other = MockBulb('AA:02', 'BLE Bulb_A9CC');
    final h = await Harness.start(FakeBle([bulb, other]));
    await h.add(bulb);
    await h.lights.rename(0x10, 'Desk');
    bulb.factoryReset();

    final found = await h.provisioning.scan().first;
    expect({for (final b in found) b.id: b.replaces}, {'AA:01': 'Desk', 'AA:02': null});
    await settle();
    expect(h.single.wasReset, isTrue);
  });

  test('adding a reset bulb again takes over its old entry', () async {
    final a = MockBulb('AA:01', 'BLE Bulb_A9CB'), b = MockBulb('AA:02', 'BLE Bulb_A9CC');
    final h = await Harness.start(FakeBle([a, b]));
    await h.add(a);
    await h.add(b);
    await h.lights.rename(0x10, 'Desk');
    a.factoryReset();
    await h.provisioning.scan().first; // notices the reset

    expect(await h.add(a), isTrue, reason: h.vm.status);
    expect(h.all.map((l) => l.name), ['Desk', 'BLE Bulb_A9CC'], reason: 'same place in the list');
    final desk = h.all.first;
    expect(desk.addr, 0x12, reason: 'a fresh address, as the spec recommends');
    expect(desk.bleId, 'AA:01');
    expect([desk.configured, desk.wasReset, desk.grouped], [true, false, true]);
    expect(h.home.home.lightAt(0x10), isNull);
    expect(h.home.deviceKey(0x10), isNull);
    expect(a.addr, 0x12);
  });
}
