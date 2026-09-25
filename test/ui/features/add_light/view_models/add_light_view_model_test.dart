import 'package:flutter_test/flutter_test.dart';
import 'package:luminar/data/services/ble/ble_service.dart';
import 'package:luminar/ui/features/add_light/view_models/add_light_view_model.dart';

import '../../../../support/harness.dart';
import '../../../../support/mock_bulb.dart';

void main() {
  test('lists unprovisioned bulbs only', () async {
    final h = await Harness.start(
      FakeBle([
        MockBulb('AA:01', 'BLE Bulb_7B2E', rssi: -80),
        MockBulb('AA:02', 'BLE Bulb_A9CB', rssi: -50),
        MockBulb.foreign('FF:01', 'BLE Bulb_ACF1'),
      ]),
    );
    final vm = AddLightViewModel(provisioning: h.provisioning);
    vm.scan();
    expect(vm.scanning, isTrue);
    await settle();
    expect(vm.found.map((b) => b.name), ['BLE Bulb_A9CB', 'BLE Bulb_7B2E']);
    expect(vm.scanning, isFalse);
    expect(vm.error, isNull);
    await vm.stop();
    vm.dispose();
  });

  test('keeps bulbs in the order they were found as the signal changes', () async {
    FoundBulb at(String id, int rssi) => FoundBulb(id, 'Bulb $id', rssi, MeshService.provisioning);
    final ble = FakeBle([])
      ..scanScript = [
        [at('A', -60)],
        [at('B', -50), at('A', -70)], // the platform sorts by signal
        [at('A', -40), at('B', -80)],
        [at('C', -30), at('A', -90), at('B', -80)],
      ];
    final h = await Harness.start(ble);
    final vm = AddLightViewModel(provisioning: h.provisioning);
    final orders = <String>{};
    vm.addListener(() => orders.add(vm.found.map((b) => b.id).join()));
    vm.scan();
    await settle();
    expect(orders, {'', 'A', 'AB', 'ABC'});
    vm.dispose();
  });

  test('smooths the signal so its label does not flicker', () async {
    FoundBulb at(int rssi) => FoundBulb('A', 'Bulb A', rssi, MeshService.provisioning);
    final ble = FakeBle([])
      ..scanScript = [
        [at(-65)],
        [at(-90)], // one bad reading
        [at(-64)],
      ];
    final h = await Harness.start(ble);
    final vm = AddLightViewModel(provisioning: h.provisioning);
    final labels = <String>{};
    vm.addListener(() {
      for (final b in vm.found) {
        labels.add(AddLightViewModel.signal(b.rssi));
      }
    });
    vm.scan();
    await settle();
    expect(labels, {'Nearby'});
    vm.dispose();
  });

  test('describes signal strength', () {
    expect(AddLightViewModel.signal(-50), 'Very close');
    expect(AddLightViewModel.signal(-70), 'Nearby');
    expect(AddLightViewModel.signal(-90), 'Far away, move closer');
  });
}
