/// Timeouts and delays. Tests shrink these.
class Timings {
  final Duration scan;

  /// How long to wait for a new proxy to prove it is on our network.
  final Duration beacon;
  final Duration provReply;
  final Duration configReply;
  final Duration reconnectBase;
  final Duration reconnectStep;
  final Duration throttle;
  const Timings({
    this.scan = const Duration(seconds: 12),
    this.beacon = const Duration(seconds: 3),
    this.provReply = const Duration(seconds: 15),
    this.configReply = const Duration(milliseconds: 3000),
    this.reconnectBase = const Duration(milliseconds: 1500),
    this.reconnectStep = const Duration(milliseconds: 1000),
    this.throttle = const Duration(milliseconds: 250),
  });

  Timings copyWith({Duration? scan, Duration? beacon}) => Timings(
    scan: scan ?? this.scan,
    beacon: beacon ?? this.beacon,
    provReply: provReply,
    configReply: configReply,
    reconnectBase: reconnectBase,
    reconnectStep: reconnectStep,
    throttle: throttle,
  );
}
