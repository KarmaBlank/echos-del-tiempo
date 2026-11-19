/// Capacidad opcional de una `NetSession`: cuánto manda el host (para la
/// línea de rendimiento de `ecos.log`; netcode.md § "Perfiles solo cuando
/// cambian"). Quien la usa pregunta `net is NetTraffic`.
abstract interface class NetTraffic {
  /// Clientes unidos ahora (host; 0 en un cliente).
  int get clientCount;

  /// Bytes del último `state` mandado (el más grande de ese envío).
  int get lastStateBytes;
}
