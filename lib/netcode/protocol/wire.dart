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

/// Versión del protocolo (`v` del `hello` / `welcome`).
const kProtocolVersion = 3;

/// Un mensaje del protocolo (docs/specs/netcode.md § "Protocolo").
sealed class WireMessage {
  const WireMessage();
}

/// cliente → host: `{"t":"hello","v":1,"p":<perfil>}`.
class HelloMessage extends WireMessage {
  const HelloMessage(this.profile, {this.version = kProtocolVersion});
  final PlayerProfile profile;
  final int version;
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
  version('El host usa otra versión del juego.');

  const RejectReason(this.message);
  final String message;
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
          },
        WelcomeMessage() => {
            't': 'welcome',
            'v': m.version,
            'id': m.id,
            'code': m.code,
          },
        RejectMessage() => {'t': 'reject', 'why': m.reason.name},
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
              version: j.integer('v'));
        case 'welcome':
          return WelcomeMessage(j.str('id'), j.str('code'),
              version: j.integer('v'));
        case 'reject':
          return RejectMessage(j.enumByName('why', RejectReason.values));
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
