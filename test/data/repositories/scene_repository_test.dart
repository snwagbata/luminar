import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/data/repositories/light_repository.dart';

import '../../support/harness.dart';
import '../../support/mock_bulb.dart';

void main() {
  test('store, list, recall and delete', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
    final h = await Harness.start(FakeBle([bulb]));
    await h.add(bulb);

    h.lights.setLevel(0x10, level: 20, kelvin: 2700);
    await settle();
    final stored = await h.scenes.store(1);
    expect(stored[0x10]!.ok, isTrue);
    expect(stored[0x10]!.scenes, [1]);

    h.lights.setLevel(0x10, level: 100, kelvin: 6500);
    await settle();
    await h.scenes.store(2);
    expect((await h.scenes.register(0x10))!.scenes, [1, 2]);

    await h.vm.recallScene(1);
    await settle();
    expect(bulb.lightness, LightRepository.toLightness(20));
    expect(bulb.kelvin, 2700);
    expect(h.single.kelvin, 2700, reason: 'state re-read after recall');

    final del = await h.scenes.delete(1);
    expect(del[0x10]!.scenes, [2]);
  });

  test('save names the scene, forget removes it everywhere', () async {
    final bulb = MockBulb('AA:01', 'BLE Bulb_7B2E');
    final h = await Harness.start(FakeBle([bulb]));
    await h.add(bulb);
    expect(await h.scenes.save('  '), 1);
    expect(await h.scenes.save('Movie'), 1);
    expect(h.scenes.names, {1: 'Scene 1', 2: 'Movie'});
    await h.scenes.forget(1);
    expect(h.scenes.names, {2: 'Movie'});
    expect(bulb.scenes.keys, [2]);
  });
}
