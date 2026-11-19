import 'dart:async';
import 'dart:convert';

import '../../game_engine/data/game_catalog.dart';
import '../../game_engine/models/game_session.dart';
import '../../game_engine/models/session_action.dart';
import '../../game_engine/models/session_event.dart';
import '../contracts/net_session.dart';
import '../contracts/net_traffic.dart';
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
/// desconexiones y el ping ([LatencyProbe], § "Ping"). Cada transporte
/// solo implementa [openRoom], [joinRoom] y [closeTransport].
abstract class ProtocolNetSession
    implements NetSession, LatencyProbe, NetTraffic {
  ProtocolNetSession({
    GameCatalog catalog = GameCatalog.standard,
    Duration Function()? clock,
    this.pingInterval = defaultPingInterval,
  })  : codec = WireCodec(catalog),
        balanceHash = catalog.balanceHash,
        _clock = clock ?? _monotonic;

  /// Hash del parche de balance propio (docs/specs/balance_admin.md § 4).
  final String balanceHash;

  final WireCodec codec;

  /// Cada cuánto se mide el ping mientras alguien escucha
  /// [latencyChanges].
  final Duration pingInterval;

  static const defaultPingInterval = Duration(seconds: 2);

  /// Un `pong` con un `ts` más viejo que esto se descarta.
  static const maxRtt = Duration(seconds: 60);

  /// Reloj monótono para el `ts` del ping (los tests inyectan uno falso).
  final Duration Function() _clock;
  static final _watch = Stopwatch()..start();
  static Duration _monotonic() => _watch.elapsed;

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
  bool _welcomed = false;

  // ---- ping (los dos) ----
  /// Última ida y vuelta por id (host: cada cliente; cliente: `h`).
  final _rtt = <String, Duration>{};
  NetLatency? _latency;
  Timer? _pingTimer;
  late final _latencyOut = StreamController<NetLatency>.broadcast(
    onListen: _startPinging,
    onCancel: _stopPinging,
  );

  @override
  bool get isHost => _isHost;

  @override
  String get localId => _localId;

  @override
  String? get roomCode => _roomCode;

  @override
  Stream<NetEvent> get events => _events.stream;

  /// Clientes unidos ahora (host).
  @override
  int get clientCount => _clients.length;

  // ------------------------------------------------------------------
  // LatencyProbe (netcode.md § "Ping")
  // ------------------------------------------------------------------

  @override
  NetLatency? get latency => _latency;

  @override
  Stream<NetLatency> get latencyChanges => _latencyOut.stream;

  void _startPinging() {
    _pingTimer?.cancel();
    if (_closed) return;
    pingNow();
    _pingTimer = Timer.periodic(pingInterval, (_) => pingNow());
  }

  void _stopPinging() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Manda un `ping` ya (host: a cada cliente unido; cliente: al host, si
  /// ya llegó el `welcome`). Lo llama el temporizador; los tests, a mano.
  void pingNow() {
    if (_closed) return;
    final text = codec.encode(PingMessage(_clock().inMicroseconds));
    if (_isHost) {
      for (final link in _clients.values) {
        link.send(text);
      }
    } else if (_welcomed) {
      _host?.send(text);
    }
  }

  /// Llegó el `pong` de [peer] con nuestro [ts].
  void _onPong(String peer, int ts) {
    final rtt = _clock() - Duration(microseconds: ts);
    if (rtt.isNegative || rtt > maxRtt) return;
    _rtt[peer] = rtt;
    _publishLatency();
  }

  void _publishLatency() {
    final l = NetLatency.aggregate(isHost: _isHost, rtts: _rtt.values);
    if (l == _latency) return;
    _latency = l;
    if (!_latencyOut.isClosed) _latencyOut.add(l);
  }

  /// Contesta el `ping` del otro lado con el mismo `ts`.
  void _pong(PeerLink link, int ts) => link.send(codec.encode(PongMessage(ts)));

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

  /// Cada cuánto el host le reenvía todos los perfiles a cada cliente
  /// aunque no hayan cambiado (respaldo; el canal ya es ordenado y fiable).
  static const profileRefresh = Duration(seconds: 10);

  /// Perfil actual de cada jugador: el objeto (atajo con `identical`), su
  /// JSON y una versión que sube cada vez que cambia.
  final _profiles = <String, ({Object profile, String json, int ver})>{};
  int _profileSeq = 0;

  /// Host: qué versión de cada perfil tiene ya cada cliente, y cuándo le
  /// llegaron todos por última vez.
  final _clientProfiles = <String, Map<String, int>>{};
  final _clientRefreshed = <String, Duration>{};

  /// Cliente: los perfiles recibidos (id → JSON).
  final _knownProfiles = <String, Object?>{};

  /// Tamaño en bytes del último `state` mandado (el más grande del
  /// tick); lo lee el registro de rendimiento.
  @override
  int lastStateBytes = 0;

  @override
  void broadcast(GameSession state, List<SessionEvent> events) {
    if (!_isHost || _closed || _clients.isEmpty) return;
    // Perfiles: solo se recodifica el que cambió de objeto, y solo sube
    // de versión si además cambió su JSON.
    final ids = <String>{};
    for (final p in state.playerList) {
      ids.add(p.id);
      final cur = _profiles[p.id];
      if (cur != null && identical(cur.profile, p.profile)) continue;
      final json = jsonEncode(p.profile.toJson());
      _profiles[p.id] = (
        profile: p.profile,
        json: json,
        ver: cur != null && cur.json == json ? cur.ver : ++_profileSeq,
      );
    }
    _profiles.removeWhere((id, _) => !ids.contains(id));

    final body = codec.stateBody(state);
    final ev = codec.stateEvents(events);
    final now = _clock();
    var biggest = 0;
    for (final MapEntry(key: pid, value: link) in _clients.entries) {
      final has = _clientProfiles.putIfAbsent(pid, () => {});
      final last = _clientRefreshed[pid];
      final refresh = last == null || now - last >= profileRefresh;
      if (refresh) _clientRefreshed[pid] = now;
      final send = <String, String>{
        for (final MapEntry(key: id, value: p) in _profiles.entries)
          if (refresh || has[id] != p.ver) id: p.json,
      };
      for (final id in send.keys) {
        has[id] = _profiles[id]!.ver;
      }
      has.removeWhere((id, _) => !_profiles.containsKey(id));
      final text = WireCodec.stateText(body, ev, send);
      if (text.length > biggest) biggest = text.length;
      link.send(text);
    }
    lastStateBytes = biggest;
  }

  @override
  Future<void> disconnect() async {
    if (_closed) return;
    _closed = true;
    _stopPinging();
    unawaited(_latencyOut.close());
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
          // Indicador de ping prendido: medir al nuevo enseguida.
          if (_latencyOut.hasListener) {
            link.send(codec.encode(PingMessage(_clock().inMicroseconds)));
          }
        } else {
          switch (msg) {
            case ActionMessage():
              _emit(PeerActionEvent(pid, msg.action));
            // Ping: control de la conexión, no una acción.
            case PingMessage():
              _pong(link, msg.ts);
            case PongMessage():
              _onPong(pid, msg.ts);
            default:
              break;
          }
        }
      },
      onError: (Object _) => unawaited(_quietly(link.close())),
      onDone: () {
        timeout.cancel();
        _pending.remove(link);
        _clientProfiles.remove(pid);
        _clientRefreshed.remove(pid);
        if (_clients.remove(pid) != null) {
          _emit(PeerLeftEvent(pid));
          if (_rtt.remove(pid) != null) _publishLatency();
        }
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
        final msg = codec.decode(text, profiles: _knownProfiles);
        switch (msg) {
          case WelcomeMessage():
            if (welcome.isCompleted) return;
            _localId = msg.id;
            _roomCode = msg.code.isEmpty ? code : msg.code;
            _welcomed = true;
            welcome.complete();
            // Si el indicador ya escuchaba, que mida enseguida.
            if (_latencyOut.hasListener) pingNow();
          case RejectMessage():
            if (!welcome.isCompleted) {
              welcome.completeError(NetException(msg.reason.message));
            }
          case StateMessage():
            if (welcome.isCompleted) {
              _emit(SnapshotEvent(msg.session, msg.events));
            }
          case PingMessage():
            if (_welcomed) _pong(link, msg.ts);
          case PongMessage():
            if (_welcomed) _onPong(hostId, msg.ts);
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
          _welcomed = false;
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
