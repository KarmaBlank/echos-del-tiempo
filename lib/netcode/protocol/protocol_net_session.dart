import 'dart:async';

import '../../game_engine/data/game_catalog.dart';
import '../../game_engine/models/game_session.dart';
import '../../game_engine/models/session_action.dart';
import '../../game_engine/models/session_event.dart';
import '../contracts/net_session.dart';
import 'wire.dart';

/// Un enlace de texto con el otro extremo (un WebSocket, un DataChannel,
/// un par de streams en memoria). Lo único que un transporte tiene que
/// saber hacer.
abstract class PeerLink {
  /// Manda un mensaje (si el enlace ya se cerró, no hace nada).
  void send(String text);

  /// Mensajes entrantes. Termina (`onDone`) cuando el enlace se cierra,
  /// de cualquiera de los dos lados. Una sola suscripción.
  Stream<String> get incoming;

  Future<void> close();
}

/// El protocolo de la sala (docs/specs/netcode.md § "Protocolo"),
/// escrito una sola vez sobre [PeerLink]: `hello` / `welcome` /
/// `reject`, acciones, `state`, sala llena, ids `h` / `p1`...,
/// desconexiones. Cada transporte solo implementa [openRoom],
/// [joinRoom] y [closeTransport].
abstract class ProtocolNetSession implements NetSession {
  ProtocolNetSession({GameCatalog catalog = GameCatalog.standard})
      : codec = WireCodec(catalog),
        balanceHash = catalog.balanceHash;

  /// Hash del parche de balance propio (docs/specs/balance_admin.md § 4).
  final String balanceHash;

  final WireCodec codec;

  /// Máximo de jugadores contando al host (`MAXP`).
  static const maxPlayers = 4;

  /// Id del host (`myId='h'` en el prototipo).
  static const hostId = 'h';

  /// Tiempo para que un enlace nuevo mande su `hello`.
  static const helloTimeout = Duration(seconds: 10);

  /// Tiempo que espera el cliente por `welcome` (15 s del prototipo).
  static const welcomeTimeout = Duration(seconds: 15);

  static const lostMessage = 'Se perdió la conexión con el host.';

  final _events = StreamController<NetEvent>();
  bool _isHost = false;
  String _localId = '';
  String? _roomCode;
  bool _closed = false;

  // ---- host ----
  final _clients = <String, PeerLink>{};
  final _pending = <PeerLink>{};
  int _nextPid = 1;

  // ---- cliente ----
  PeerLink? _host;

  @override
  bool get isHost => _isHost;

  @override
  String get localId => _localId;

  @override
  String? get roomCode => _roomCode;

  @override
  Stream<NetEvent> get events => _events.stream;

  /// Clientes unidos ahora (host).
  int get clientCount => _clients.length;

  // ------------------------------------------------------------------
  // Transporte (lo implementa cada variante; solo los llama esta clase)
  // ------------------------------------------------------------------

  /// Host: abre la sala y llama a [onPeer] con cada conexión entrante.
  /// Devuelve el código de la sala. Lanza [NetException] si no pudo.
  Future<String> openRoom(void Function(PeerLink link) onPeer);

  /// Cliente: abre un enlace con el host de [code]. Lanza [NetException]
  /// si no pudo.
  Future<PeerLink> joinRoom(String code);

  /// Cierra lo propio del transporte (servidor, señalización...).
  Future<void> closeTransport();

  /// Para la variante: avisar que el transporte del host murió.
  void transportLost(String reason) => _emit(ConnectionLostEvent(reason));

  // ------------------------------------------------------------------
  // NetSession
  // ------------------------------------------------------------------

  @override
  Future<void> connect(SessionConfig config) async {
    if (_closed) throw StateError('NetSession ya desconectada');
    final code = config.roomCode;
    if (code == null) {
      _isHost = true;
      _localId = hostId;
      _roomCode = await openRoom(_onPeer);
    } else {
      await _join(code, config);
    }
  }

  @override
  void sendAction(SessionAction action) {
    if (_isHost || _closed) return;
    _host?.send(codec.encode(ActionMessage(action)));
  }

  @override
  void broadcast(GameSession state, List<SessionEvent> events) {
    if (!_isHost || _closed || _clients.isEmpty) return;
    final text = codec.encode(StateMessage(state, events));
    for (final link in _clients.values) {
      link.send(text);
    }
  }

  @override
  Future<void> disconnect() async {
    if (_closed) return;
    _closed = true;
    final links = [..._clients.values, ..._pending, if (_host != null) _host!];
    _clients.clear();
    _pending.clear();
    _host = null;
    for (final l in links) {
      await _quietly(l.close());
    }
    await _quietly(closeTransport());
    // Sin `await`: un stream de una suscripción que nadie escuchó nunca
    // no completa su `close()`.
    unawaited(_events.close());
  }

  static Future<void> _quietly(Future<void> f) async {
    try {
      await f;
    } on Object {
      // Cerrar algo que ya estaba cerrado no es un error para el juego.
    }
  }

  void _emit(NetEvent e) {
    if (!_closed && !_events.isClosed) _events.add(e);
  }

  // ------------------------------------------------------------------
  // Host
  // ------------------------------------------------------------------

  void _onPeer(PeerLink link) {
    if (_closed) {
      unawaited(_quietly(link.close()));
      return;
    }
    final pid = 'p${_nextPid++}';
    _pending.add(link);
    var joined = false;
    final timeout = Timer(helloTimeout, () {
      if (!joined) unawaited(_quietly(link.close()));
    });
    link.incoming.listen(
      (text) {
        final msg = codec.decode(text);
        if (msg == null) return;
        if (!joined) {
          if (msg is! HelloMessage) return;
          timeout.cancel();
          final reject = msg.version != kProtocolVersion
              ? RejectReason.version
              : balanceReject(msg.balance, balanceHash) ??
                  (_clients.length + 1 >= maxPlayers
                      ? RejectReason.full
                      : null);
          if (reject != null) {
            link.send(codec.encode(RejectMessage(reject)));
            // `setTimeout(()=>c.close(),300)`: que llegue el mensaje.
            Timer(const Duration(milliseconds: 300),
                () => unawaited(_quietly(link.close())));
            return;
          }
          joined = true;
          _pending.remove(link);
          _clients[pid] = link;
          link.send(codec.encode(WelcomeMessage(pid, _roomCode ?? '')));
          _emit(PeerJoinedEvent(pid, msg.profile));
        } else if (msg is ActionMessage) {
          _emit(PeerActionEvent(pid, msg.action));
        }
      },
      onError: (Object _) => unawaited(_quietly(link.close())),
      onDone: () {
        timeout.cancel();
        _pending.remove(link);
        if (_clients.remove(pid) != null) _emit(PeerLeftEvent(pid));
      },
      cancelOnError: false,
    );
  }

  // ------------------------------------------------------------------
  // Cliente
  // ------------------------------------------------------------------

  Future<void> _join(String code, SessionConfig config) async {
    final link = await joinRoom(code);
    if (_closed) {
      await _quietly(link.close());
      throw const NetException('Conexión cancelada.');
    }
    _host = link;
    final welcome = Completer<void>();
    link.incoming.listen(
      (text) {
        final msg = codec.decode(text);
        switch (msg) {
          case WelcomeMessage():
            if (welcome.isCompleted) return;
            _localId = msg.id;
            _roomCode = msg.code.isEmpty ? code : msg.code;
            welcome.complete();
          case RejectMessage():
            if (!welcome.isCompleted) {
              welcome.completeError(NetException(msg.reason.message));
            }
          case StateMessage():
            if (welcome.isCompleted) {
              _emit(SnapshotEvent(msg.session, msg.events));
            }
          default:
            break;
        }
      },
      onError: (Object _) => unawaited(_quietly(link.close())),
      onDone: () {
        if (!welcome.isCompleted) {
          welcome.completeError(
              const NetException('El host cerró la conexión.'));
        } else if (!_closed) {
          _host = null;
          _emit(const ConnectionLostEvent(lostMessage));
        }
      },
      cancelOnError: false,
    );
    link.send(
        codec.encode(HelloMessage(config.profile, balance: balanceHash)));
    try {
      await welcome.future.timeout(welcomeTimeout,
          onTimeout: () => throw const NetException(
              'No se pudo conectar (tiempo agotado). Revisa el código o '
              'que el host siga con el juego abierto.'));
    } on Object {
      _host = null;
      await _quietly(link.close());
      rethrow;
    }
  }
}
