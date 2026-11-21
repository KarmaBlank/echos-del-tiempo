import '../../../game_engine/data/exploration_catalog.dart';
import '../../../game_engine/models/game_map.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/rules/exploration_rules.dart';
import '../../../game_engine/rules/zone_rules.dart';

/// Textos del mapa del mundo y de los pisos (avisos y carteles). Ver
/// docs/specs/exploration.md § "Mundo y pisos".

/// Qué pasa con E frente a una entrada de zona.
enum EntranceAction {
  /// Proponer la misión de la zona.
  propose,

  /// Votar que sí (ya hay votación por esa misión).
  voteYes,

  /// Nada: bloqueada, próximamente, otra votación o ya votó.
  none,
}

/// Qué hace E frente a la entrada de [z] con la votación [vote].
EntranceAction entranceAction(
    ZoneStatus z, MissionVote? vote, String localId) {
  final m = z.mission;
  if (!z.open || m == null) return EntranceAction.none;
  if (vote == null) return EntranceAction.propose;
  if (vote.missionId == m.id && !vote.yes.contains(localId)) {
    return EntranceAction.voteYes;
  }
  return EntranceAction.none;
}

/// Aviso frente a la entrada de [z].
String entrancePromptText(ZoneStatus z, MissionVote? vote, String localId) {
  final zone = z.zone;
  final info = '${zone.name} · ${zone.levelText}';
  if (!z.open) return '$info · ${z.label}';
  return switch (entranceAction(z, vote, localId)) {
    EntranceAction.propose => '[E] Entrar: ${zone.name} (${zone.levelText})',
    EntranceAction.voteYes => '[E] Votar SÍ: ${zone.name}',
    EntranceAction.none => vote?.missionId == z.mission?.id
        ? '${zone.name} · Esperando al resto...'
        : '${zone.name} · Ya hay una votación',
  };
}

/// `[E] Bajar al piso N` / `[E] Subir al piso N` desde el piso [floor]
/// (desde 0).
String stairsPromptText(StairsKind kind, int floor) => kind == StairsKind.down
    ? '[E] Bajar al piso ${floor + 2}'
    : '[E] Subir al piso $floor';

/// Cartel de E frente a un punto de interés (worldgen.md § 11.3).
String poiPromptText(MapPoi p, MissionRun m, MapFloor f, double time) {
  switch (p.kind) {
    case PoiKind.secret:
      return '[E] Romper la pared agrietada';
    case PoiKind.shortcut:
      return '[E] Abrir el atajo';
    case PoiKind.brazier:
      return '[E] Encender el brasero';
    case PoiKind.shrine:
      final b = kBlessings[
          BlessingKind.values[p.variant % BlessingKind.values.length]]!;
      return '[E] Santuario: ${b.name} (${b.effect})';
    case PoiKind.wind:
      return time < m.windUntil
          ? '[E] Viento del Eco (renovar)'
          : '[E] Viento del Eco: +${((kWindSpeed - 1) * 100).round()}% '
              'velocidad ${kWindSeconds.round()} s';
    case PoiKind.waystone:
      if (!m.poiUsed.contains(p.id)) return '[E] Activar la piedra de paso';
      if (ExplorationRules.waystoneDestinations(f, m, p).isEmpty) {
        return 'Piedra de paso: activá otra para viajar';
      }
      return '[E] Elegir destino en el mapa';
    case PoiKind.relic:
      return '';
  }
}
