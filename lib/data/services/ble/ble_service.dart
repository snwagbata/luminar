import 'dart:async';
import 'dart:typed_data';

/// Mesh GATT services.
enum MeshService {
  /// PB-GATT, 0x1827. Advertised by unprovisioned bulbs.
  provisioning,

  /// Mesh Proxy, 0x1828. Advertised by provisioned bulbs.
  proxy,
}

/// A bulb seen while scanning.
class FoundBulb {
  final String id;
  final String name;
  final int rssi;
  final MeshService service;

  /// Mesh Proxy service data (Network ID or Node Identity), if advertised.
  final Uint8List? proxyData;
  FoundBulb(this.id, this.name, this.rssi, this.service, {this.proxyData});
}

/// An open GATT connection to one bulb's provisioning or proxy service.
abstract class MeshLink {
  String get id;

  /// Largest write, including the proxy header byte (MTU − 3).
  int get maxChunk;

  /// Raw notifications from Data Out. Single-subscription; buffers until
  /// listened to.
  Stream<Uint8List> get notifications;

  /// Completes when the connection drops.
  Future<void> get done;

  /// Writes one chunk to Data In (write without response).
  Future<void> write(Uint8List chunk);

  Future<void> disconnect();
}

class BluetoothUnavailable implements Exception {
  final String message;
  BluetoothUnavailable(this.message);
  @override
  String toString() => message;
}

/// Thrown when a connected bulb does not offer the requested mesh service,
/// for example right after provisioning while Android still has its old
/// GATT table cached.
class ServiceNotFound implements Exception {
  @override
  String toString() => 'Mesh service not found';
}

abstract class BleService {
  /// Throws [BluetoothUnavailable] if Bluetooth is off or not permitted.
  Future<void> ensureReady();

  /// Emits the growing list of bulbs advertising any of [services],
  /// strongest first. Each bulb says which service it offers.
  Stream<List<FoundBulb>> scan(Set<MeshService> services, {Duration timeout});

  Future<void> stopScan();

  /// Connects and opens [service]. [fresh] asks the platform to drop cached
  /// GATT services first.
  Future<MeshLink> connect(String id, MeshService service, {bool fresh = false});
}

/// Serializes writes to a link, splitting nothing: callers pass ready chunks.
class LinkWriter {
  final MeshLink link;
  Future<void> _chain = Future.value();
  LinkWriter(this.link);

  Future<void> writeAll(List<Uint8List> chunks) {
    final next = _chain.then((_) async {
      for (final c in chunks) {
        await link.write(c);
      }
    });
    _chain = next.catchError((_) {});
    return next;
  }
}
