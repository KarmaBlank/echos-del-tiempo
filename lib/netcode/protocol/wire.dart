import 'dart:convert';

import '../../game_engine/data/game_catalog.dart';
import '../../game_engine/models/game_session.dart';
import '../../game_engine/models/player_profile.dart';
import '../../game_engine/models/session_action.dart';
import '../../game_engine/models/session_event.dart';
import '../../game_engine/serialization/action_json.dart';
import '../../game_engine/serialization/event_json.dart';
import '../../game_engine/serialization/json_read.dart';
import '../../game_engine/serialization/session_json.dart';

/// Versión del protocolo (`v` del `hello` / `welcome`). 6 desde v0.5.1:
/// acción `wants` (resumen del plan de build para la condición `Build`
/// del filtro de loot; docs/specs/netcode.md § "Build y filtro").
const kProtocolVersion = 6;

/// Un mensaje del protocolo (docs/specs/netcode.md § "Protocolo").
sealed class WireMessage {
  const WireMessage();
}

/// cliente → host: `{"t":"hello","v":1,"p":<perfil>,"b":<hash>}`.
class HelloMessage extends WireMessage {
  const HelloMessage(this.profile,
      {this.version = kProtocolVersion, this.balance});
  final PlayerProfile profile;
  final int version;

  /// Hash del parche de balance del cliente (`GameCatalog.balanceHash`,
  /// docs/specs/balance_admin.md § 4). `null` = cliente anterior al
  /// balance por archivo (equivale a sin parche).
  final String? balance;
}

/// host → cliente: `{"t":"welcome","v":1,"id":"p1","code":"ABCDE"}`.
class WelcomeMessage extends WireMessage {
  const WelcomeMessage(this.id, this.code, {this.version = kProtocolVersion});
  final String id;
  final String code;
  final int version;
}

/// Por qué el host rechaza a un cliente.
enum RejectReason {
  full('La sala está llena (máx. 4).'),
  version('El host usa otra versión del juego.'),
  balance('El host tiene otro parche de balance: actualizá el juego.');

  const RejectReason(this.message);
  final String message;
}

/// Si el host rechaza a un cliente por el parche de balance (§ 4 de
/// docs/specs/balance_admin.md). Un cliente sin hash ([client] `null`,
/// versión anterior) cuenta como sin parche y se le contesta `version`
/// (no conoce el motivo `balance`).
RejectReason? balanceReject(String? client, String host) {
  final mine = client ?? GameCatalog.baseBalanceHash;
  if (mine == host) return null;
  return client == null ? RejectReason.version : RejectReason.balance;
}

/// host → cliente: `{"t":"reject","why":"full"}` (y cierra).
class RejectMessage extends WireMessage {
  const RejectMessage(this.reason);
  final RejectReason reason;
}

/// cliente → host: cualquier `SessionAction` (`{"t":"pos",...}`...).
class ActionMessage extends WireMessage {
  const ActionMessage(this.action);
  final SessionAction action;
}

/// host → cliente: `{"t":"state","s":<GameSession>,"ev":[...]}`.
class StateMessage extends WireMessage {
  const StateMessage(this.session, this.events);
  final GameSession session;
  final List<SessionEvent> events;
}

/// Cualquiera de los dos lados: `{"t":"ping","ts":123456}`. [ts] son
/// microsegundos del reloj de quien lo manda; el otro lo devuelve igual
/// en un [PongMessage] (docs/specs/netcode.md § "Ping"). No es una
/// acción: nunca toca el estado de la sala.
class PingMessage extends WireMessage {
  const PingMessage(this.ts);
  final int ts;
}

/// Respuesta a un [PingMessage]: `{"t":"pong","ts":123456}`.
class PongMessage extends WireMessage {
  const PongMessage(this.ts);
  final int ts;
}

/// Codifica / decodifica mensajes del protocolo como texto JSON.
class WireCodec {
  WireCodec([GameCatalog catalog = GameCatalog.standard])
      : session = SessionJson(catalog),
        events = EventJson(SessionJson(catalog));

  final SessionJson session;
  final EventJson events;

  String encode(WireMessage m) => jsonEncode(switch (m) {
        HelloMessage() => {
            't': 'hello',
            'v': m.version,
            'p': m.profile.toJson(),
            if (m.balance != null) 'b': m.balance,
          },
        WelcomeMessage() => {
            't': 'welcome',
            'v': m.version,
            'id': m.id,
            'code': m.code,
          },
        RejectMessage() => {'t': 'reject', 'why': m.reason.name},
        PingMessage() => {'t': 'ping', 'ts': m.ts},
        PongMessage() => {'t': 'pong', 'ts': m.ts},
        ActionMessage() => ActionJson.toJson(m.action),
        StateMessage() => {
            't': 'state',
            's': session.toJson(m.session),
            'ev': [for (final e in m.events) events.toJson(e)],
          },
      });

  /// `null` si el texto no es un mensaje válido (se ignora, como hace el
  /// `switch` de `onMsg` con un `t` desconocido).
  WireMessage? decode(String text) {
    try {
      final j = asJson(jsonDecode(text));
      switch (j.str('t')) {
        case 'hello':
          return HelloMessage(PlayerProfile.fromJson(j.obj('p')),
              version: j.integer('v'), balance: j.strOrNull('b'));
        case 'welcome':
          return WelcomeMessage(j.str('id'), j.str('code'),
              version: j.integer('v'));
        case 'reject':
          return RejectMessage(j.enumByName('why', RejectReason.values));
        case 'ping':
          return PingMessage(j.integer('ts'));
        case 'pong':
          return PongMessage(j.integer('ts'));
        case 'state':
          return StateMessage(
            session.fromJson(j.obj('s')),
            List.unmodifiable([
              for (final raw in j.list('ev')) events.fromJson(asJson(raw)),
            ]),
          );
        default:
          return ActionMessage(ActionJson.fromJson(j));
      }
    } on Object {
      return null;
    }
  }
}
