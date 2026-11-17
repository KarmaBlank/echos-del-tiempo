import 'dart:async';

import '../../game_engine/data/game_catalog.dart';
import '../contracts/net_session.dart';
import '../protocol/protocol_net_session.dart';

/// "Internet" en memoria: las salas abiertas por código. Un hub por test
/// (o por proceso) conecta un host con N clientes sin sockets.
class LoopbackHub {
  final _rooms = <String, void Function(PeerLink)>{};
  int _next = 1;

  /// Salas abiertas ahora.
  Iterable<String> get rooms => _rooms.keys;

  String _open(void Function(PeerLink) onPeer) {
    final code = 'LOOP${_next++}';
    _rooms[code] = onPeer;
    return code;
  }

  void _close(String code) => _rooms.remove(code);

  PeerLink _connect(String code) {
    final onPeer = _rooms[code.trim().toUpperCase()];
    if (onPeer == null) {
      throw NetException('Sala $code no encontrada.');
    }
    final a = _LoopLink();
    final b = _LoopLink();
    a._other = b;
    b._other = a;
    onPeer(b);
    return a;
  }
}

/// Un extremo de un par de enlaces en memoria. Los mensajes se entregan
/// de forma asíncrona (como por red) y en orden.
class _LoopLink implements PeerLink {
  final _in = StreamController<String>();
  _LoopLink? _other;
  bool _closed = false;

  @override
  Stream<String> get incoming => _in.stream;

  @override
  void send(String text) {
    final o = _other;
    if (_closed || o == null || o._closed) return;
    o._in.add(text);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    unawaited(_in.close());
    final o = _other;
    if (o != null && !o._closed) {
      o._closed = true;
      unawaited(o._in.close());
    }
  }
}

/// [NetSession] en memoria sobre un [LoopbackHub]: el mismo protocolo y
/// la misma codificación JSON que los transportes reales, para probar
/// host + clientes en un solo proceso. Ver docs/specs/netcode.md.
class LoopbackNetSession extends ProtocolNetSession {
  LoopbackNetSession(this.hub, {super.catalog = GameCatalog.standard});

  final LoopbackHub hub;
  String? _code;

  @override
  Future<String> openRoom(void Function(PeerLink link) onPeer) async =>
      _code = hub._open(onPeer);

  @override
  Future<PeerLink> joinRoom(String code) async => hub._connect(code);

  @override
  Future<void> closeTransport() async {
    final c = _code;
    if (c != null) hub._close(c);
  }
}
