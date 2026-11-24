import 'dart:collection';

import 'game_session.dart';

/// Clave de la instancia del pueblo (siempre existe).
const kTownRoom = 'pueblo';

/// Las instancias de una sala (docs/specs/free_movement.md § 2): el
/// pueblo, los exteriores de bioma con alguien y las mazmorras en juego.
/// Cada jugador está en exactamente una.
///
/// Solo del anfitrión (no viaja): cada cliente recibe su instancia. Es un
/// contenedor mutable que maneja `WorldEngine`; las [GameSession] de
/// adentro se reemplazan, nunca se tocan en el lugar.
class SessionWorld {
  SessionWorld(GameSession town)
      : rooms = LinkedHashMap.of({kTownRoom: town});

  /// Instancias por clave: `pueblo`, el id del bioma o `d1`, `d2`...
  final LinkedHashMap<String, GameSession> rooms;

  /// Contador para las claves de mazmorra.
  int nextDungeon = 1;

  /// Firma de quién está dónde (para recalcular `away` solo si cambia).
  String awaySig = '';

  /// The open gathering (free_movement.md § 2.1), copied to every
  /// instance when it changes.
  Gathering? gather;
  String gatherSig = '';

  GameSession get town => rooms[kTownRoom]!;

  /// La clave de la instancia donde está [playerId], o `null`.
  String? roomOf(String playerId) {
    for (final e in rooms.entries) {
      if (e.value.players.containsKey(playerId)) return e.key;
    }
    return null;
  }

  /// La instancia de [playerId], o `null`.
  GameSession? sessionOf(String playerId) {
    final k = roomOf(playerId);
    return k == null ? null : rooms[k];
  }

  /// Todos los jugadores de todas las instancias.
  Iterable<SessionPlayer> get allPlayers =>
      rooms.values.expand((r) => r.playerList);

  static final _dungeonKey = RegExp(r'^d\d+$');
  static bool isDungeon(String key) => _dungeonKey.hasMatch(key);
}
