/// A bulb found by a scan.
class NearbyBulb {
  /// Platform Bluetooth id (MAC on Android).
  final String id;
  final String name;

  /// Signal strength in dBm.
  final int rssi;

  /// The name of the light this bulb was before it was reset, if it was one
  /// of ours.
  final String? replaces;

  const NearbyBulb({required this.id, required this.name, required this.rssi, this.replaces});
}
