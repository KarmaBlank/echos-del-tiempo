/// Resumen de la latencia de una sala (docs/specs/netcode.md § "Ping").
class NetLatency {
  const NetLatency({
    required this.isHost,
    required this.rtt,
    required this.max,
    required this.peers,
  });

  /// Arma el resumen con las idas y vueltas medidas: cliente, la del host
  /// (una); host, una por cliente (promedio y peor).
  factory NetLatency.aggregate({
    required bool isHost,
    required Iterable<Duration> rtts,
  }) {
    final list = rtts.toList();
    if (list.isEmpty) {
      return NetLatency(isHost: isHost, rtt: null, max: null, peers: 0);
    }
    var sum = 0;
    var worst = Duration.zero;
    for (final d in list) {
      sum += d.inMicroseconds;
      if (d > worst) worst = d;
    }
    return NetLatency(
      isHost: isHost,
      rtt: Duration(microseconds: (sum / list.length).round()),
      max: worst,
      peers: list.length,
    );
  }

  /// true si lo midió el host (contra sus clientes).
  final bool isHost;

  /// Cliente: ida y vuelta al host. Host: el promedio de sus clientes.
  /// `null` = nada medido (host sin clientes, o antes del primer `pong`).
  final Duration? rtt;

  /// El peor (host); en el cliente, igual a [rtt].
  final Duration? max;

  /// Cuántas mediciones entran en el resumen.
  final int peers;

  @override
  bool operator ==(Object other) =>
      other is NetLatency &&
      other.isHost == isHost &&
      other.rtt == rtt &&
      other.max == max &&
      other.peers == peers;

  @override
  int get hashCode => Object.hash(isHost, rtt, max, peers);

  @override
  String toString() => 'NetLatency(host: $isHost, rtt: $rtt, max: $max, '
      'peers: $peers)';
}

/// Capacidad opcional de una `NetSession`: medir el ping. Aparte de
/// `NetSession` para no obligar a cada implementación (ni a las falsas de
/// los tests) a medir; quien la usa pregunta `net is LatencyProbe`.
abstract interface class LatencyProbe {
  /// La última medición (`null` = todavía nada).
  NetLatency? get latency;

  /// Cada medición nueva (broadcast). Mientras alguien escucha se mide
  /// enseguida y después cada ~2 s; sin oyentes no viaja ningún `ping`.
  Stream<NetLatency> get latencyChanges;
}
