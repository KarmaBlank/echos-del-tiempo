import 'dart:async';
import 'dart:io';

import '../../game_engine/data/game_catalog.dart';
import '../contracts/net_session.dart';
import '../protocol/protocol_net_session.dart';

/// [NetSession] para jugar en la misma red local (o dos ventanas en la
/// misma PC) sin Firebase: el host abre un servidor WebSocket y el
/// código de sala es su `IP:PUERTO`. Ver docs/specs/netcode.md § "LAN".
class LanNetSession extends ProtocolNetSession {
  LanNetSession({
    this.port = defaultPort,
    this.advertisedHost,
    this.bindLoopbackOnly = false,
    super.catalog = GameCatalog.standard,
    super.maxPlayers,
    super.game,
  });

  /// Puerto preferido; si está ocupado se usa uno libre.
  static const defaultPort = 47800;

  /// Ruta del WebSocket.
  static const path = '/ecos';

  static const connectTimeout = Duration(seconds: 8);

  final int port;

  /// IP que se muestra en el código (tests: `127.0.0.1`). `null` = la
  /// primera IPv4 privada de la PC.
  final String? advertisedHost;

  /// Escuchar solo en 127.0.0.1 (tests: sin aviso del firewall).
  final bool bindLoopbackOnly;

  HttpServer? _server;
  final _sockets = <WebSocket>{};

  /// Todas las IPv4 de la PC que no son loopback, las privadas primero
  /// (`192.168.*`, `10.*`, `172.16-31.*`).
  static Future<List<String>> lanAddresses() async {
    List<NetworkInterface> ifaces;
    try {
      ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    } on Object {
      return const [];
    }
    final all = [
      for (final i in ifaces)
        for (final a in i.addresses)
          if (!a.isLoopback) a.address,
    ];
    int rank(String ip) {
      if (ip.startsWith('192.168.')) return 0;
      if (ip.startsWith('10.')) return 1;
      final parts = ip.split('.');
      final second = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      if (ip.startsWith('172.') && second >= 16 && second <= 31) return 2;
      return 3;
    }

    all.sort((a, b) => rank(a).compareTo(rank(b)));
    return all;
  }

  /// `IP[:PUERTO]` → (host, puerto). `null` si no se puede leer.
  static (String, int)? parseCode(String code) {
    final c = code.trim();
    if (c.isEmpty) return null;
    final i = c.lastIndexOf(':');
    if (i < 0) return (c, defaultPort);
    final host = c.substring(0, i).trim();
    final p = int.tryParse(c.substring(i + 1).trim());
    if (host.isEmpty || p == null || p <= 0 || p > 65535) return null;
    return (host, p);
  }

  @override
  Future<String> openRoom(void Function(PeerLink link) onPeer) async {
    final address = bindLoopbackOnly
        ? InternetAddress.loopbackIPv4
        : InternetAddress.anyIPv4;
    HttpServer server;
    try {
      server = await HttpServer.bind(address, port);
    } on SocketException {
      try {
        // Otra sala en esta PC ya usa el puerto: uno libre cualquiera.
        server = await HttpServer.bind(address, 0);
      } on SocketException catch (e) {
        throw NetException('No se pudo abrir la sala: ${e.message}');
      }
    }
    _server = server;
    server.listen((req) async {
      if (req.uri.path != path || !WebSocketTransformer.isUpgradeRequest(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      try {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.pingInterval = const Duration(seconds: 5);
        _sockets.add(ws);
        onPeer(_WsLink(ws, onClosed: () => _sockets.remove(ws)));
      } on Object {
        // Un handshake roto no afecta a la sala.
      }
    }, onError: (Object e) => transportLost('La sala dejó de aceptar conexiones.'));
    final ip = advertisedHost ?? (await lanAddresses()).firstOrNull ?? '127.0.0.1';
    return '$ip:${server.port}';
  }

  @override
  Future<PeerLink> joinRoom(String code) async {
    final parsed = parseCode(code);
    if (parsed == null) {
      throw const NetException('Código inválido: usa IP:PUERTO (p. ej. 192.168.1.23:47800).');
    }
    final (host, p) = parsed;
    try {
      final ws = await WebSocket.connect('ws://$host:$p$path')
          .timeout(connectTimeout);
      ws.pingInterval = const Duration(seconds: 5);
      return _WsLink(ws);
    } on TimeoutException {
      throw NetException('No se pudo conectar a $host:$p (tiempo agotado). '
          '¿Están en la misma red y el host tiene la sala abierta?');
    } on Object {
      throw NetException('Sala $host:$p no encontrada. '
          '¿El host sigue con el juego abierto?');
    }
  }

  @override
  Future<void> closeTransport() async {
    for (final ws in [..._sockets]) {
      try {
        await ws.close();
      } on Object {
        // ya cerrado
      }
    }
    _sockets.clear();
    await _server?.close(force: true);
    _server = null;
  }
}

/// Un WebSocket como [PeerLink] (solo mensajes de texto).
class _WsLink implements PeerLink {
  _WsLink(this._ws, {void Function()? onClosed}) {
    _ws.listen(
      (data) {
        if (data is String && !_in.isClosed) _in.add(data);
      },
      onError: (Object _) => _finish(),
      onDone: _finish,
      cancelOnError: true,
    );
    _onClosed = onClosed;
  }

  final WebSocket _ws;
  final _in = StreamController<String>();
  void Function()? _onClosed;

  void _finish() {
    _onClosed?.call();
    _onClosed = null;
    if (!_in.isClosed) unawaited(_in.close());
  }

  @override
  Stream<String> get incoming => _in.stream;

  @override
  void send(String text) {
    if (_ws.readyState == WebSocket.open) _ws.add(text);
  }

  @override
  Future<void> close() async {
    try {
      await _ws.close().timeout(const Duration(seconds: 2));
    } on Object {
      // ya cerrado o el otro lado no responde
    }
    _finish();
  }
}
